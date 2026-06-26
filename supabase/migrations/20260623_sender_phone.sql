-- Add sender_phone to orders for P2P colis orders (person handing over the package)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS sender_phone TEXT;
