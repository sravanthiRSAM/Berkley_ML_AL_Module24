"""
Extract 2026 Customer Provisioning Tickets (CPT) from the internal
`dpaas_uccatalog_prd.pdbia.cpt_active_tickets` table into a local CSV
for the capstone EDA.

Privacy: the `assignee` column contains employee email addresses. It is
one-way hashed to a stable pseudonymous id (assignee_hash) so per-assignee
workload can still be analyzed without exposing identities. No other
PII/customer columns (names, emails, org names) are exported.

Auth: uses the Databricks CLI unified auth (DEFAULT profile in
~/.databrickscfg). Run `databricks auth login` first if it fails.
"""
import os
import pandas as pd
from databricks import sql

HOST = "adb-2960179772222895.15.azuredatabricks.net"
HTTP_PATH = "/sql/1.0/warehouses/4c3ffac6cd725ed6"
OUT = os.path.join(os.path.dirname(__file__), "data", "cpt_active_tickets_2026.csv")

# Analytical columns only. String 'None' literals -> NULL. assignee -> hash.
QUERY = r"""
SELECT
    ticket_id,
    create_date,
    update_date,
    due_date,
    start_date,
    end_date,
    implementation_date,
    effective_date,
    NULLIF(status, 'None')          AS status,
    NULLIF(status_reason, 'None')   AS status_reason,
    NULLIF(type, 'None')            AS type,
    NULLIF(order_type, 'None')      AS order_type,
    NULLIF(order_reason, 'None')    AS order_reason,
    NULLIF(requestor_system, 'None') AS requestor_system,
    NULLIF(sourceofrecords, 'None') AS sourceofrecords,
    NULLIF(geo, 'None')             AS geo,
    NULLIF(country, 'None')         AS country,
    NULLIF(market_segment, 'None')  AS market_segment,
    NULLIF(cloud, 'None')           AS cloud,
    NULLIF(offer_family, 'None')    AS offer_family,
    NULLIF(offer_id, 'None')        AS offer_id,
    TRY_CAST(NULLIF(offer_quantity, 'None') AS DOUBLE) AS offer_quantity,
    NULLIF(acm_id, 'None')          AS acm_id,
    CASE WHEN assignee IS NULL OR assignee = 'None' THEN NULL
         ELSE concat('A_', substr(sha2(assignee, 256), 1, 10)) END AS assignee_hash
FROM dpaas_uccatalog_prd.pdbia.cpt_active_tickets
WHERE year(create_date) = 2026
ORDER BY create_date
"""

def main():
    with sql.connect(server_hostname=HOST, http_path=HTTP_PATH) as conn:
        df = pd.read_sql(QUERY, conn)
    df.to_csv(OUT, index=False)
    print(f"Wrote {len(df):,} rows x {df.shape[1]} cols -> {OUT}")
    print("Columns:", list(df.columns))

if __name__ == "__main__":
    main()
