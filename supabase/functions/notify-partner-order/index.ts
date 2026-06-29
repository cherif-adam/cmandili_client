import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"
import { JWT } from "https://esm.sh/google-auth-library@9"

// Type pour le payload du webhook Supabase
interface WebhookPayload {
  type: 'INSERT' | 'UPDATE'
  table: string
  record: any
  schema: string
  old_record: any | null
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json()
    
    // On ne s'intéresse qu'aux commandes qui viennent de passer en 'pending'
    if (payload.record.status !== 'pending') {
      return new Response(JSON.stringify({ message: "Status is not pending, ignored." }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      })
    }

    // Initialiser le client Supabase avec le rôle Service Role pour bypasser le RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    const supabase = createClient(supabaseUrl, supabaseKey)

    const entityId = payload.record.restaurant_id || payload.record.supermarket_id
    if (!entityId) {
      throw new Error("No restaurant_id or supermarket_id found in order.")
    }

    // 1. Trouver le(s) partenaire(s) rattaché(s) à cette entité
    const { data: profiles, error: profileError } = await supabase
      .from('partner_profiles')
      .select('user_id')
      .eq('entity_id', entityId)

    if (profileError || !profiles || profiles.length === 0) {
      throw new Error(`Partner profile not found for entity: ${entityId}`)
    }

    // On récupère tous les user_id liés à cette entité (généralement 1)
    const userIds = profiles.map(p => p.user_id)

    // 2. Trouver les tokens d'appareils de ces partenaires
    const { data: devices, error: deviceError } = await supabase
      .from('device_tokens')
      .select('token')
      .in('user_id', userIds)

    if (deviceError || !devices || devices.length === 0) {
      return new Response(JSON.stringify({ message: "No devices found for this partner." }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      })
    }

    const tokens = devices.map(d => d.token)

    // 3. Préparer l'authentification Google Cloud pour l'API FCM HTTP v1
    // Le Service Account doit être stocké dans les secrets Supabase :
    // supabase secrets set GOOGLE_SERVICE_ACCOUNT="..."
    const serviceAccountJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT")
    if (!serviceAccountJson) {
      throw new Error("Missing GOOGLE_SERVICE_ACCOUNT secret")
    }
    
    const serviceAccount = JSON.parse(serviceAccountJson)
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    })
    
    const token = await jwtClient.getAccessToken()
    const accessToken = token.token

    const projectId = serviceAccount.project_id
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    // 4. Envoyer le message FCM (Data-only pour déclencher le handler en arrière-plan)
    const sendPromises = tokens.map(async (fcmToken) => {
      const response = await fetch(fcmEndpoint, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            data: {
              type: "new_order",
              title: "Nouvelle commande !",
              body: `Commande #${payload.record.id.substring(0, 8).toUpperCase()} en attente d'acceptation.`,
              orderId: payload.record.id,
            },
            // Note: On N'INCLUT PAS le champ "notification" ici.
            // On veut que le message soit un "data message" pour que Flutter 
            // prenne le relais et affiche la notification avec le son insistant.
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  "content-available": 1 // Force le réveil de l'app sur iOS
                }
              }
            }
          }
        }),
      })

      if (!response.ok) {
        console.error(`Error sending to ${fcmToken}:`, await response.text())
      }
    })

    await Promise.all(sendPromises)

    return new Response(JSON.stringify({ message: "Notifications sent successfully" }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })

  } catch (error: any) {
    console.error("Function error:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    })
  }
})
