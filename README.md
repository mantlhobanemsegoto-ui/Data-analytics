# Sizwe Coffee SQL Analysis

## Project overview

This project analyses Sizwe Coffee's year-end business performance for the two financial years from 1 July 2023 to 30 June 2025. Sizwe Coffee is a Johannesburg-based roastery and wholesale supplier serving approximately 1,400 business customers through Wholesale and Subscription channels.

The analysis answers eight questions for the Financial Director and National Sales Manager:

1. Revenue performance by channel
2. Profit and margin by product line
3. Invoice settlement and outstanding debt by channel
4. The ten largest FY2025 customer accounts
5. High-revenue Wholesale customers without trade promotions
6. Sales representative performance against monthly target
7. Monthly revenue, month-on-month change and a rolling three-month average
8. The product-mix reason for the decline in gross margin

## Dataset

| Table | Purpose | Main relationship |
|---|---|---|
| `customers` | Customer details, channel, segment, province and assigned representative | `customer_id` joins to orders, ledger and promotions |
| `products` | Product, product line, selling price and unit cost | `sku` joins to sales lines |
| `sales_orders` | Order header, customer, date, representative and channel | `order_id` joins to sales lines |
| `sales_lines` | Units, price, discount, revenue and cost of goods | Revenue is measured here |
| `ar_ledger` | Invoice, amount settled and settlement date | `customer_id` joins to customers |
| `reps` | Representative name, territory and monthly target | `rep_id` joins to orders and customers |
| `rep_visits` | Customer visits and outcomes | Not required in the eight final queries |
| `trade_promotions` | Customer and product promotional support | Used to identify customers with no promotion |
| `vendors` | Supplier information | Not required in the eight final queries |

Revenue is stored at sales-line level, so all revenue calculations join `sales_orders` to `sales_lines`. The financial year runs from 1 July to 30 June.

## Skills demonstrated

- **Joins:** Tasks 1-8 connect order, line, customer, product and representative data.
- **Conditional aggregation:** Tasks 1 and 8 place FY2024 and FY2025 figures side by side.
- **`CASE` expressions:** Tasks 1 and 8 classify transactions into financial years.
- **Aggregate functions:** Tasks 1-8 use `SUM`, `COUNT` and `AVG` for business measures.
- **Left joins:** Tasks 4 and 6 retain unassigned customers and representatives with no revenue.
- **Anti-join with `NOT EXISTS`:** Task 5 finds Wholesale customers who never received a promotion.
- **Common table expressions:** Tasks 5-8 separate calculations into readable stages.
- **Window functions:** Task 7 uses `LAG` and a rolling `AVG`; Task 8 calculates each product line's share of total revenue.
- **Safe division:** `NULLIF` prevents divide-by-zero errors.

## How to run

1. Open DuckDB, DBeaver with DuckDB, or another PostgreSQL-compatible SQL tool.
2. Import the Excel worksheets as tables using these names:
   - `Customers` -> `customers`
   - `Products` -> `products`
   - `Sales orders` -> `sales_orders`
   - `Sales line` -> `sales_lines`
   - `AR Ledger` -> `ar_ledger`
   - `Reps` -> `reps`
   - `Reps visits` -> `rep_visits`
   - `Trade promotions` -> `trade_promotions`
   - `Vendor` -> `vendors`
3. Open `queries.sql` and run the queries in task order.
4. Confirm that dates are loaded as date values and revenue/cost fields are numeric.

Example DuckDB import pattern after converting each worksheet to CSV:

```sql
CREATE TABLE sales_orders AS
SELECT * FROM read_csv_auto('sales_orders.csv', header = true);
```

## Key insights

- **Channel growth was balanced.** Wholesale increased from **R308.17m to R335.43m (8.85%)**, while Subscription increased from **R132.83m to R144.57m (8.84%)**.
- **House Blend generated the most gross profit:** **R107.15m**. **Single Origin** produced the highest gross margin at **44.27%**.
- **Wholesale is the collections priority.** It had **3,454 open invoices**, **R87.85m outstanding**, and an average settlement time of **68.68 days**. Subscription had **44 open invoices** and **R0.75m outstanding**.
- **Halvane Retail Group was the largest FY2025 customer**, generating **R38.40m**.
- **Most representatives exceeded target.** Karabo van Wyk ranked first at **250.32%** of target. Sipho Steyn reached **97.99%**, and Johan Naidoo reached **77.63%**.
- **December is the seasonal low point.** December 2023 was the quietest month at **R29.87m**, followed by steady growth toward a June peak.
- **The margin decline was driven by product mix.** Bulk Commercial has a margin of about **19.9%**, but its revenue share rose from **25.02% to 33.65%**. At the same time, House Blend's share fell from **32.14% to 28.71%** and Single Origin's share fell from **19.45% to 17.57%**. This moved the total margin from **34.69% to 33.00%** despite revenue increasing from **R441m to R480m**.

## Data-quality note

The supplied workbook's **Trade promotions** worksheet is blank, although the assignment brief states that it should contain 640 records. Task 5 is therefore written correctly but its final ranking and recommendation must be rerun after the missing promotion data is added. With the current workbook, every Wholesale customer is treated as having never received a promotion.
