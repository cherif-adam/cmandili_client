-- Add package_size to orders for P2P colis orders (Petit / Moyen / Grand)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS package_size TEXT
    CHECK (package_size IN ('petit', 'moyen', 'grand'));
