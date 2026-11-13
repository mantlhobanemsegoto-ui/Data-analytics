-- Sizwe Coffee SQL Assignment
-- Dialect: PostgreSQL-compatible SQL (also runs in DuckDB)

-- Task 1: Channel performance
SELECT
    so.channel,
    ROUND(SUM(CASE WHEN so.order_date <= DATE '2024-06-30' THEN sl.line_revenue ELSE 0 END), 2) AS fy2024_revenue,
    ROUND(SUM(CASE WHEN so.order_date >  DATE '2024-06-30' THEN sl.line_revenue ELSE 0 END), 2) AS fy2025_revenue,
    ROUND(
        100.0 * (
            SUM(CASE WHEN so.order_date > DATE '2024-06-30' THEN sl.line_revenue ELSE 0 END)
            / NULLIF(SUM(CASE WHEN so.order_date <= DATE '2024-06-30' THEN sl.line_revenue ELSE 0 END), 0)
            - 1
        ), 2
    ) AS growth_pct
FROM sales_orders AS so
JOIN sales_lines AS sl ON sl.order_id = so.order_id
GROUP BY so.channel
ORDER BY so.channel;

-- Answer: Wholesale revenue increased from R308.17m to R335.43m (8.85%), while Subscription increased from R132.83m to R144.57m (8.84%). Growth was therefore balanced across both channels, with Wholesale remaining the larger channel.

-- Task 2: Where the profit actually comes from
SELECT
    p.product_line,
    ROUND(SUM(sl.line_revenue), 2) AS revenue,
    ROUND(SUM(sl.cogs), 2) AS cost_of_goods,
    ROUND(SUM(sl.line_revenue - sl.cogs), 2) AS gross_profit,
    ROUND(100.0 * SUM(sl.line_revenue - sl.cogs) / NULLIF(SUM(sl.line_revenue), 0), 2) AS gross_margin_pct
FROM sales_lines AS sl
JOIN products AS p ON p.sku = sl.sku
GROUP BY p.product_line
ORDER BY gross_profit DESC;

-- Answer: House Blend earns the most gross profit at R107.15m. It is not the highest-margin line: Single Origin has the highest gross margin at 44.27%, compared with House Blend at 38.33%.

-- Task 3: The collections problem
SELECT
    c.channel,
    COUNT(*) AS invoice_count,
    COUNT(*) FILTER (WHERE ar.amount_settled >= ar.invoice_amount) AS settled_count,
    COUNT(*) FILTER (WHERE ar.amount_settled < ar.invoice_amount) AS open_count,
    ROUND(AVG(ar.settlement_date - ar.invoice_date)
          FILTER (WHERE ar.amount_settled >= ar.invoice_amount), 2) AS avg_days_to_settle,
    ROUND(SUM(GREATEST(ar.invoice_amount - ar.amount_settled, 0)), 2) AS total_outstanding
FROM ar_ledger AS ar
JOIN customers AS c ON c.customer_id = ar.customer_id
GROUP BY c.channel
ORDER BY c.channel;

-- Answer: Wholesale is the clear collections risk: 3,454 invoices remain open, R87.85m is outstanding and settled invoices take 68.68 days on average. Subscription has only 44 open invoices, R0.75m outstanding and an average settlement time of 3.85 days, so Wholesale should be investigated first.

-- Task 4: The ten accounts that matter most
SELECT
    c.trading_name,
    c.segment,
    c.province,
    COALESCE(r.rep_name, 'Unassigned') AS sales_representative,
    ROUND(SUM(sl.line_revenue), 2) AS fy2025_revenue
FROM sales_orders AS so
JOIN sales_lines AS sl ON sl.order_id = so.order_id
JOIN customers AS c ON c.customer_id = so.customer_id
LEFT JOIN reps AS r ON r.rep_id = c.rep_id
WHERE so.order_date BETWEEN DATE '2024-07-01' AND DATE '2025-06-30'
GROUP BY c.customer_id, c.trading_name, c.segment, c.province, r.rep_name
ORDER BY fy2025_revenue DESC
LIMIT 10;

-- Task 5: A commercial gap
WITH wholesale_revenue AS (
    SELECT
        so.customer_id,
        SUM(sl.line_revenue) AS revenue
    FROM sales_orders AS so
    JOIN sales_lines AS sl ON sl.order_id = so.order_id
    WHERE so.channel = 'Wholesale'
    GROUP BY so.customer_id
)
SELECT
    c.trading_name,
    c.segment,
    c.province,
    ROUND(wr.revenue, 2) AS revenue
FROM wholesale_revenue AS wr
JOIN customers AS c ON c.customer_id = wr.customer_id
WHERE NOT EXISTS (
    SELECT 1
    FROM trade_promotions AS tp
    WHERE tp.customer_id = wr.customer_id
)
ORDER BY wr.revenue DESC
LIMIT 15;

-- Answer: Prioritise the top three accounts for an immediate commercial review, confirm whether their lack of support is intentional, and test a targeted promotion with measurable volume and margin goals. Note: the supplied Trade promotions worksheet is blank, so the numeric ranking currently treats every Wholesale customer as never promoted and must be rerun when the intended 640 promotion records are supplied.

-- Task 6: Are the sales representatives hitting target?
WITH rep_revenue AS (
    SELECT
        so.rep_id,
        SUM(sl.line_revenue) AS fy2025_revenue
    FROM sales_orders AS so
    JOIN sales_lines AS sl ON sl.order_id = so.order_id
    WHERE so.order_date BETWEEN DATE '2024-07-01' AND DATE '2025-06-30'
    GROUP BY so.rep_id
)
SELECT
    r.rep_name,
    r.territory,
    r.target_monthly,
    ROUND(COALESCE(rr.fy2025_revenue, 0) / 12.0, 2) AS actual_fy2025_monthly_average,
    ROUND(100.0 * (COALESCE(rr.fy2025_revenue, 0) / 12.0) / NULLIF(r.target_monthly, 0), 2) AS pct_of_target
FROM reps AS r
LEFT JOIN rep_revenue AS rr ON rr.rep_id = r.rep_id
ORDER BY pct_of_target DESC, r.rep_name;

-- Task 7: The shape of the year
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', so.order_date)::DATE AS revenue_month,
        SUM(sl.line_revenue) AS monthly_revenue
    FROM sales_orders AS so
    JOIN sales_lines AS sl ON sl.order_id = so.order_id
    GROUP BY DATE_TRUNC('month', so.order_date)::DATE
),
monthly_with_previous AS (
    SELECT
        revenue_month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (ORDER BY revenue_month) AS previous_month_revenue
    FROM monthly
)
SELECT
    revenue_month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND(100.0 * (monthly_revenue / NULLIF(previous_month_revenue, 0) - 1), 2) AS change_from_previous_month_pct,
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY revenue_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_three_month_average
FROM monthly_with_previous
ORDER BY revenue_month;

-- Answer: The same pattern appears in both years: revenue falls from October through December, then recovers steadily from January and peaks in June. December is the quietest month, with December 2023 the lowest point at R29.87m.

-- Task 8: Why has the margin moved?
WITH line_year AS (
    SELECT
        p.product_line,
        CASE WHEN so.order_date <= DATE '2024-06-30' THEN 'FY2024' ELSE 'FY2025' END AS financial_year,
        SUM(sl.line_revenue) AS revenue,
        SUM(sl.cogs) AS cogs
    FROM sales_orders AS so
    JOIN sales_lines AS sl ON sl.order_id = so.order_id
    JOIN products AS p ON p.sku = sl.sku
    GROUP BY p.product_line,
             CASE WHEN so.order_date <= DATE '2024-06-30' THEN 'FY2024' ELSE 'FY2025' END
),
metrics AS (
    SELECT
        product_line,
        financial_year,
        revenue,
        100.0 * (revenue - cogs) / NULLIF(revenue, 0) AS gross_margin_pct,
        100.0 * revenue / SUM(revenue) OVER (PARTITION BY financial_year) AS revenue_share_pct
    FROM line_year
)
SELECT
    product_line,
    ROUND(MAX(CASE WHEN financial_year = 'FY2024' THEN revenue END), 2) AS fy2024_revenue,
    ROUND(MAX(CASE WHEN financial_year = 'FY2024' THEN gross_margin_pct END), 2) AS fy2024_margin_pct,
    ROUND(MAX(CASE WHEN financial_year = 'FY2024' THEN revenue_share_pct END), 2) AS fy2024_revenue_share_pct,
    ROUND(MAX(CASE WHEN financial_year = 'FY2025' THEN revenue END), 2) AS fy2025_revenue,
    ROUND(MAX(CASE WHEN financial_year = 'FY2025' THEN gross_margin_pct END), 2) AS fy2025_margin_pct,
    ROUND(MAX(CASE WHEN financial_year = 'FY2025' THEN revenue_share_pct END), 2) AS fy2025_revenue_share_pct
FROM metrics
GROUP BY product_line
ORDER BY fy2025_revenue DESC;

-- Answer: The decline was caused mainly by product mix, not a sharp fall in each line's own margin. Bulk Commercial, the lowest-margin line at about 19.9%, grew from R110.34m to R161.50m and its revenue share rose from 25.02% to 33.65%; meanwhile, higher-margin House Blend fell from 32.14% to 28.71% of revenue and Single Origin fell from 19.45% to 17.57%. This shift toward Bulk Commercial pulled Sizwe's total gross margin down from 34.69% to 33.00% even though total revenue grew from R441m to R480m.
