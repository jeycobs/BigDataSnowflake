INSERT INTO dim_locations (postal_code, city, state, country)
SELECT DISTINCT
    COALESCE(customer_postal_code, 'N/A') as postal_code,
    COALESCE(customer_country, 'N/A') as city,
    'N/A' as state,
    COALESCE(customer_country, 'N/A') as country
FROM mock_data_raw
WHERE customer_postal_code IS NOT NULL OR customer_country IS NOT NULL 
ON CONFLICT (postal_code, city, state, country) DO NOTHING;

INSERT INTO dim_locations (postal_code, city, state, country)
SELECT DISTINCT
    COALESCE(seller_postal_code, 'N/A') as postal_code,
    'N/A' as city, 
    'N/A' as state, 
    COALESCE(seller_country, 'N/A') as country
FROM mock_data_raw
WHERE seller_postal_code IS NOT NULL OR seller_country IS NOT NULL
ON CONFLICT (postal_code, city, state, country) DO NOTHING;

INSERT INTO dim_locations (postal_code, city, state, country)
SELECT DISTINCT
    'N/A' as postal_code, 
    COALESCE(store_city, 'N/A') as city,
    COALESCE(store_state, 'N/A') as state,
    COALESCE(store_country, 'N/A') as country
FROM mock_data_raw
WHERE store_city IS NOT NULL OR store_state IS NOT NULL OR store_country IS NOT NULL
ON CONFLICT (postal_code, city, state, country) DO NOTHING;

INSERT INTO dim_customers (customer_nk_id, first_name, last_name, age, email, location_sk)
SELECT DISTINCT
    m.sale_customer_id,
    m.customer_first_name,
    m.customer_last_name,
    m.customer_age,
    m.customer_email,
    dl.location_sk
FROM mock_data_raw m
LEFT JOIN dim_locations dl ON dl.postal_code = COALESCE(m.customer_postal_code, 'N/A')
                         AND dl.city = COALESCE(m.customer_country, 'N/A')
                         AND dl.state = 'N/A'
                         AND dl.country = COALESCE(m.customer_country, 'N/A')
WHERE m.sale_customer_id IS NOT NULL
ON CONFLICT (customer_nk_id) DO NOTHING;

INSERT INTO dim_customer_pets (customer_sk, pet_type, pet_name, pet_breed, pet_category)
SELECT DISTINCT
    dc.customer_sk,
    m.customer_pet_type,
    m.customer_pet_name,
    m.customer_pet_breed,
    m.pet_category
FROM mock_data_raw m
JOIN dim_customers dc ON m.sale_customer_id = dc.customer_nk_id
WHERE m.customer_pet_name IS NOT NULL
ON CONFLICT (customer_sk, pet_type, pet_name, pet_breed) DO NOTHING;

INSERT INTO dim_sellers (seller_nk_id, first_name, last_name, email, location_sk)
SELECT DISTINCT
    m.sale_seller_id,
    m.seller_first_name,
    m.seller_last_name,
    m.seller_email,
    dl.location_sk
FROM mock_data_raw m
LEFT JOIN dim_locations dl ON dl.postal_code = COALESCE(m.seller_postal_code, 'N/A')
                         AND dl.city = 'N/A'
                         AND dl.state = 'N/A'
                         AND dl.country = COALESCE(m.seller_country, 'N/A')
WHERE m.sale_seller_id IS NOT NULL
ON CONFLICT (seller_nk_id) DO NOTHING;

INSERT INTO dim_suppliers (name, contact_person, email, phone, address, city, country)
SELECT DISTINCT
    m.supplier_name,
    m.supplier_contact,
    m.supplier_email,
    m.supplier_phone,
    m.supplier_address,
    m.supplier_city,
    m.supplier_country
FROM mock_data_raw m
WHERE m.supplier_name IS NOT NULL
ON CONFLICT (name) DO NOTHING;

INSERT INTO dim_products (product_nk_id, name, category, current_price, current_quantity, weight, color, size, brand, material, description, rating, reviews, release_date, expiry_date)
SELECT DISTINCT
    m.sale_product_id,
    m.product_name,
    m.product_category,
    m.product_price,
    m.product_quantity,
    m.product_weight,
    m.product_color,
    m.product_size,
    m.product_brand,
    m.product_material,
    m.product_description,
    m.product_rating,
    m.product_reviews,
    m.product_release_date,
    m.product_expiry_date
FROM mock_data_raw m
WHERE m.sale_product_id IS NOT NULL
ON CONFLICT (product_nk_id) DO UPDATE SET 
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    current_price = EXCLUDED.current_price,
    current_quantity = EXCLUDED.current_quantity,
    weight = EXCLUDED.weight,
    color = EXCLUDED.color,
    size = EXCLUDED.size,
    brand = EXCLUDED.brand,
    material = EXCLUDED.material,
    description = EXCLUDED.description,
    rating = EXCLUDED.rating,
    reviews = EXCLUDED.reviews,
    release_date = EXCLUDED.release_date,
    expiry_date = EXCLUDED.expiry_date;


INSERT INTO dim_stores (name, location_details, phone, email, location_sk)
SELECT DISTINCT
    m.store_name,
    m.store_location,
    m.store_phone,
    m.store_email,
    dl.location_sk
FROM mock_data_raw m
LEFT JOIN dim_locations dl ON dl.postal_code = 'N/A'
                         AND dl.city = COALESCE(m.store_city, 'N/A')
                         AND dl.state = COALESCE(m.store_state, 'N/A')
                         AND dl.country = COALESCE(m.store_country, 'N/A')
WHERE m.store_name IS NOT NULL
ON CONFLICT (name, location_details, location_sk) DO NOTHING;

INSERT INTO dim_dates (date_sk, full_date, year, quarter, month, month_name, day, day_of_week, day_name, week_of_year)
SELECT
    TO_CHAR(sale_date, 'YYYYMMDD')::INTEGER AS date_sk,
    sale_date AS full_date,
    EXTRACT(YEAR FROM sale_date) AS year,
    EXTRACT(QUARTER FROM sale_date) AS quarter,
    EXTRACT(MONTH FROM sale_date) AS month,
    TO_CHAR(sale_date, 'Month') AS month_name,
    EXTRACT(DAY FROM sale_date) AS day,
    EXTRACT(ISODOW FROM sale_date) AS day_of_week, 
    TO_CHAR(sale_date, 'Day') AS day_name,
    EXTRACT(WEEK FROM sale_date) AS week_of_year
FROM (SELECT DISTINCT sale_date FROM mock_data_raw WHERE sale_date IS NOT NULL) AS unique_dates
ON CONFLICT (date_sk) DO NOTHING;


INSERT INTO fact_sales (
    date_sk, customer_sk, pet_sk, seller_sk, product_sk, store_sk, supplier_sk,
    quantity_sold, unit_price_at_sale, total_price_at_sale, raw_data_id
)
SELECT
    d_date.date_sk,
    d_cust.customer_sk,
    COALESCE(d_pet.pet_sk, -1), 
    d_sell.seller_sk,
    d_prod.product_sk,
    d_store.store_sk,
    COALESCE(d_supp.supplier_sk, -1), 
    m.sale_quantity,
    CASE
        WHEN m.sale_quantity IS NOT NULL AND m.sale_quantity != 0 THEN m.sale_total_price / m.sale_quantity
        ELSE 0
    END AS unit_price_at_sale,
    m.sale_total_price,
    m.id
FROM mock_data_raw m
LEFT JOIN dim_dates d_date ON d_date.full_date = m.sale_date
LEFT JOIN dim_customers d_cust ON d_cust.customer_nk_id = m.sale_customer_id
LEFT JOIN dim_customer_pets d_pet ON d_pet.customer_sk = d_cust.customer_sk
                                 AND d_pet.pet_type = m.customer_pet_type
                                 AND d_pet.pet_name = m.customer_pet_name
                                 AND d_pet.pet_breed = m.customer_pet_breed
LEFT JOIN dim_sellers d_sell ON d_sell.seller_nk_id = m.sale_seller_id
LEFT JOIN dim_products d_prod ON d_prod.product_nk_id = m.sale_product_id
LEFT JOIN dim_suppliers d_supp ON d_supp.name = m.supplier_name 
LEFT JOIN dim_locations dloc_store ON dloc_store.postal_code = 'N/A'
                                  AND dloc_store.city = COALESCE(m.store_city, 'N/A')
                                  AND dloc_store.state = COALESCE(m.store_state, 'N/A')
                                  AND dloc_store.country = COALESCE(m.store_country, 'N/A')
LEFT JOIN dim_stores d_store ON d_store.name = m.store_name
                            AND d_store.location_details = m.store_location
                            AND d_store.location_sk = dloc_store.location_sk 
WHERE d_date.date_sk IS NOT NULL
  AND d_cust.customer_sk IS NOT NULL
  AND d_sell.seller_sk IS NOT NULL
  AND d_prod.product_sk IS NOT NULL
  AND d_store.store_sk IS NOT NULL;
