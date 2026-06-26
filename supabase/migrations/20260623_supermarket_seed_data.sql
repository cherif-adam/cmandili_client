-- ── Tunisian supermarket seed data ──────────────────────────────────────────
-- Adds one realistic Tunisian supermarket and ~50 products.
-- Safe to re-run: uses DO block to skip if supermarket already exists.

DO $$
DECLARE
  v_sm_id UUID := gen_random_uuid();
BEGIN
  -- Only insert if no supermarkets exist yet
  IF NOT EXISTS (SELECT 1 FROM public.supermarkets LIMIT 1) THEN

    INSERT INTO public.supermarkets
      (id, name, description, image_url, rating, review_count,
       delivery_time_min, delivery_fee, min_order, is_open, latitude, longitude)
    VALUES
      (v_sm_id,
       'Monoprix Sousse',
       'Votre supermarché de proximité — épicerie, produits frais, hygiène et bien plus',
       '',
       4.3, 128, 35, 3.500, 15.000, true, 35.8256, 10.6369),
      (gen_random_uuid(),
       'Carrefour Market Kairouan',
       'Large choix de produits alimentaires et ménagers au meilleur prix',
       '',
       4.1, 87, 40, 3.500, 15.000, true, 35.6735, 10.0966);

    -- ── Légumes (vegetables) ──────────────────────────────────────────────
    INSERT INTO public.grocery_items
      (supermarket_id, name, description, image_url, price, category, unit, is_organic, is_available)
    VALUES
      (v_sm_id, 'Tomates', 'Tomates fraîches du marché', '', 0.700, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Pommes de terre', 'Pommes de terre de qualité', '', 0.600, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Oignons', 'Oignons secs', '', 0.500, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Carottes', 'Carottes fraîches', '', 0.800, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Poivrons rouges', 'Poivrons rouges charnus', '', 1.500, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Courgettes', 'Courgettes vertes fraîches', '', 0.900, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Piments forts', 'Piments rouges forts', '', 1.200, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Ail', 'Ail blanc sec', '', 3.500, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Concombres', 'Concombres frais', '', 0.700, 'vegetables', 'kg', false, true),
      (v_sm_id, 'Laitue', 'Laitue iceberg', '', 1.200, 'vegetables', 'pièce', false, true),

    -- ── Fruits ────────────────────────────────────────────────────────────
      (v_sm_id, 'Oranges', 'Oranges de Sicile ou Tunisie', '', 1.500, 'fruits', 'kg', false, true),
      (v_sm_id, 'Bananes', 'Bananes Cavendish', '', 2.000, 'fruits', 'kg', false, true),
      (v_sm_id, 'Pommes Golden', 'Pommes Golden importées', '', 3.200, 'fruits', 'kg', false, true),
      (v_sm_id, 'Pastèque', 'Pastèque entière ~5 kg', '', 4.500, 'fruits', 'pièce', false, true),
      (v_sm_id, 'Raisins noirs', 'Raisins noirs sans pépins', '', 3.500, 'fruits', 'kg', false, true),
      (v_sm_id, 'Grenade', 'Grenades tunisiennes', '', 2.500, 'fruits', 'kg', false, true),
      (v_sm_id, 'Citrons', 'Citrons jaunes', '', 1.800, 'fruits', 'kg', false, true),

    -- ── Produits laitiers (dairy) ─────────────────────────────────────────
      (v_sm_id, 'Lait Délice demi-écrémé 1L', 'Lait pasteurisé demi-écrémé', '', 1.850, 'dairy', 'L', false, true),
      (v_sm_id, 'Lait Vitalait entier 1L', 'Lait entier UHT Vitalait', '', 1.750, 'dairy', 'L', false, true),
      (v_sm_id, 'Yaourt nature Délice ×4', 'Yaourts nature 4×125 g', '', 2.900, 'dairy', 'lot', false, true),
      (v_sm_id, 'Lben Vitalait 1L', 'Lait fermenté traditionnel', '', 1.600, 'dairy', 'L', false, true),
      (v_sm_id, 'Fromage fondu Kiri 8P', 'Fromage à tartiner Kiri 8 portions', '', 4.500, 'dairy', 'boîte', false, true),
      (v_sm_id, 'Beurre Président 200g', 'Beurre doux Président', '', 7.800, 'dairy', 'g', false, true),
      (v_sm_id, 'Fromage Edam 200g', 'Fromage Edam tranché', '', 5.900, 'dairy', 'g', false, true),
      (v_sm_id, 'Crème fraîche Délice 200ml', 'Crème fraîche épaisse', '', 2.600, 'dairy', 'ml', false, true),

    -- ── Boissons (beverages) ──────────────────────────────────────────────
      (v_sm_id, 'Eau Saida 1,5L', 'Eau minérale naturelle Saida', '', 0.600, 'beverages', 'L', false, true),
      (v_sm_id, 'Eau Hayet 1,5L', 'Eau minérale naturelle Hayet', '', 0.550, 'beverages', 'L', false, true),
      (v_sm_id, 'Jus orange Tiky 1L', 'Jus d''orange 100% naturel Tiky', '', 3.200, 'beverages', 'L', false, true),
      (v_sm_id, 'Boga Cola 1,5L', 'Boisson gazeuse cola Boga', '', 2.200, 'beverages', 'L', false, true),
      (v_sm_id, 'Boga Orange 1,5L', 'Boisson gazeuse orange Boga', '', 2.200, 'beverages', 'L', false, true),
      (v_sm_id, 'Café Bon Café 250g', 'Café moulu torréfié Bon Café', '', 8.500, 'beverages', 'g', false, true),
      (v_sm_id, 'Thé Lipton Yellow 25 sachets', 'Thé noir Lipton en sachets', '', 4.200, 'beverages', 'boîte', false, true),
      (v_sm_id, 'Nectar pamplemousse Jus''Cool 1L', 'Nectar de pamplemousse Jus''Cool', '', 3.000, 'beverages', 'L', false, true),

    -- ── Boulangerie (bakery) ──────────────────────────────────────────────
      (v_sm_id, 'Pain de mie 500g', 'Pain de mie tranché moelleux', '', 2.200, 'bakery', 'g', false, true),
      (v_sm_id, 'Baguette', 'Baguette de pain frais', '', 0.190, 'bakery', 'pièce', false, true),
      (v_sm_id, 'Croissant au beurre', 'Croissant feuilleté au beurre', '', 0.900, 'bakery', 'pièce', false, true),
      (v_sm_id, 'Msemen ×6', 'Msemen traditionnels feuilletés ×6', '', 2.000, 'bakery', 'lot', false, true),
      (v_sm_id, 'Biscuits Slama Petit Beurre 200g', 'Biscuits petit beurre Slama', '', 1.900, 'bakery', 'g', false, true),

    -- ── Viande et poisson (meat) ──────────────────────────────────────────
      (v_sm_id, 'Poulet fermier entier 1kg', 'Poulet élevé en plein air', '', 8.500, 'meat', 'kg', false, true),
      (v_sm_id, 'Escalope de dinde 500g', 'Tranches de dinde fraîches', '', 7.200, 'meat', 'g', false, true),
      (v_sm_id, 'Viande hachée bœuf 500g', 'Viande hachée fraîche du boucher', '', 17.000, 'meat', 'g', false, true),
      (v_sm_id, 'Merguez agneau 500g', 'Merguez traditionnelles au piment', '', 10.500, 'meat', 'g', false, true),
      (v_sm_id, 'Sardines fraîches 500g', 'Sardines de pêche locale', '', 4.800, 'meat', 'g', false, true),
      (v_sm_id, 'Thon Le Pêcheur 185g', 'Thon entier à l''huile d''olive', '', 2.900, 'meat', 'boîte', false, true),

    -- ── Snacks ────────────────────────────────────────────────────────────
      (v_sm_id, 'Chips Slama Nature 100g', 'Chips croustillantes nature Slama', '', 1.900, 'snacks', 'g', false, true),
      (v_sm_id, 'Chocolat Nucrema 400g', 'Pâte à tartiner au chocolat Nucrema', '', 6.800, 'snacks', 'g', false, true),
      (v_sm_id, 'Biscuits Bonjour ×3', 'Biscuits fourrés chocolat Bonjour ×3', '', 2.700, 'snacks', 'lot', false, true),
      (v_sm_id, 'Cacahuètes grillées 250g', 'Arachides grillées salées', '', 2.400, 'snacks', 'g', false, true),
      (v_sm_id, 'Gâteaux El Bey assortis 200g', 'Gâteaux secs assortis El Bey', '', 3.500, 'snacks', 'g', false, true),
      (v_sm_id, 'Pop-corn micro-ondes 3×100g', 'Pop-corn au beurre micro-ondes', '', 4.200, 'snacks', 'lot', false, true),

    -- ── Ménage / Hygiène (household) ─────────────────────────────────────
      (v_sm_id, 'Lessive Bonux 1kg', 'Poudre à laver toutes couleurs Bonux', '', 8.200, 'household', 'kg', false, true),
      (v_sm_id, 'Liquide vaisselle Fairy 500ml', 'Détergent vaisselle citron Fairy', '', 4.700, 'household', 'ml', false, true),
      (v_sm_id, 'Papier hygiénique Lotus ×6', 'Rouleau papier hygiénique Lotus', '', 4.500, 'household', 'lot', false, true),
      (v_sm_id, 'Savon Lifebuoy 90g', 'Savon antibactérien Lifebuoy', '', 1.300, 'household', 'g', false, true),
      (v_sm_id, 'Shampooing Pantene 200ml', 'Shampooing réparateur Pantene', '', 8.200, 'household', 'ml', false, true),
      (v_sm_id, 'Eau de Javel 1L', 'Eau de Javel concentrée', '', 2.100, 'household', 'L', false, true),
      (v_sm_id, 'Essuie-tout Lotus ×2', 'Essuie-tout extra-absorbant ×2', '', 3.800, 'household', 'lot', false, true),
      (v_sm_id, 'Désodorisant Glade 300ml', 'Spray désodorisant Glade lavande', '', 9.500, 'household', 'ml', false, true);

  END IF;
END $$;
