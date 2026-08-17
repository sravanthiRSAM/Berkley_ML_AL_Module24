### Forecasting Customer Provisioning Ticket Volume & Resolution Effort

**Author:** Sravanthi Gandu

> **In plain terms.** The moment a provisioning ticket arrives, this project scores it two
> ways: *how long it will take* and *whether it will miss its promised due date*. The
> deadline-risk model is the standout — when it flags a ticket as at-risk it is right about
> **4 out of 5 times** and catches roughly **two-thirds** of tickets that eventually breach,
> giving the team a day-one heads-up instead of finding out only after an SLA is already
> missed. The biggest warning signs are a **tight promised deadline**, certain
> **product lines** (e.g. data-services/analytics), and **larger multi-item tickets**. The
> practical payoff: triage risky tickets early and set honest expectations up front, rather
> than reacting to spikes after they happen.

#### Executive summary

Provisioning teams currently react to spikes in Customer Provisioning Tickets (CPT)
*after* they happen, which leads to missed SLAs and last-minute staffing scrambles. This
project uses internal ticket data (2026 year-to-date, ~49K order line items
across ~19K tickets) to (1) understand what drives how long a ticket takes to resolve and
(2) lay the groundwork for forecasting incoming ticket volume.

This report covers the exploratory data analysis (EDA) and two supervised models that use
only information available **at intake**: (1) a **regression** model that predicts *how long*
a ticket will take to resolve, and (2) a **classification** model that flags *whether* a
ticket will breach its committed due date. Several model families were compared with
5-fold cross-validation and tuned with grid search. The tuned **Gradient Boosting** regressor
explains **~48%** of the variance in (log) resolution time, and the **breach classifier**
reaches **ROC-AUC 0.90** — together giving operations both a predicted duration and an
at-risk flag the moment a ticket arrives, plus a ranked, human-readable list of the factors
that drive delay.

#### Rationale

Why should anyone care about this question? Because reacting late is expensive.
Overstaffing in quiet periods wastes money; understaffing in busy periods breaks SLAs and
erodes customer trust. If managers can *see the wave coming* and know *which tickets will
be heavy*, they can plan headcount ahead of time, shift work toward bottleneck areas, and
warn customers early instead of after a deadline slips. The goal is a simpler, calmer
planning process that operations staff can act on without needing to understand the model
behind it.

#### Research Question

Can we forecast the volume of incoming Customer Provisioning Tickets (CPT) and predict the
resolution effort of each ticket at intake, in order to anticipate workload and flag
at-risk tickets before they breach SLA?

#### Model outcomes & type of learning

Both models are **supervised**:

- **Resolution effort → regression.** Target: `resolution_days` (continuous), modeled on a
  `log1p` scale and reported back in real days. Output: a predicted number of days to resolve.
- **SLA breach → binary classification.** Target: `breached` = 1 if a ticket resolves *after*
  its committed `due_date`. Output: a breach probability / at-risk flag at intake.

#### Data Sources

- **Internal `cpt_active_tickets` table** from the provisioning system
  (`dpaas_uccatalog_prd.pdbia.cpt_active_tickets` in Databricks Unity Catalog).
- This report uses the **2026 year-to-date** slice: **49,486** order line items spanning
  **18,667** distinct tickets, from 2026-01-01 to 2026-08-17.
- The extract keeps analytical fields only — ticket dates (`create_date`, `due_date`,
  `start_date`, `end_date`, `implementation_date`), status fields (`status`,
  `status_reason`, `type`, `order_type`, `order_reason`), business dimensions (`geo`,
  `country`, `market_segment`, `cloud`, `offer_family`), and workload keys.
- **Privacy:** the `assignee` field (employee email) is one-way hashed to `assignee_hash`
  at extraction, and no customer/employee PII (names, emails, org names) is included in
  this repository. The extraction query lives in [`extract_data.py`](extract_data.py).

#### Methodology

- **Data cleaning:** robust ISO-8601 date parsing, removal of exact-duplicate rows,
  correction of negative (back-dated) resolution durations, IQR-based flagging of
  long-running outliers (kept, not deleted, since they are the "at-risk" cases of
  interest), and explicit `"UNKNOWN"` imputation of missing categoricals.
- **Feature engineering:** derived the target `resolution_days`
  (`implementation_date − create_date`), intake-time calendar features
  (month, ISO week, day-of-week, hour), and `line_items_per_ticket` as a ticket-size proxy.
- **EDA & visualization:** pandas, Seaborn/Matplotlib, and Plotly to explore categorical
  distributions, the (heavily right-skewed) resolution-time distribution, resolution time
  across business dimensions, a numeric correlation matrix, and the weekly/monthly ticket
  arrival pattern.
- **Preprocessing (shared):** a scikit-learn `ColumnTransformer` — one-hot encoding for
  categoricals (rare levels collapsed via `min_frequency`), median imputation + standardization
  for numerics — fit **inside each cross-validation fold** so no test information leaks. An
  **80/20 train/test split** (stratified for the classifier) is held out for final evaluation.
- **Regression modeling (Notebook 3):** compared **Ridge, Lasso, ElasticNet, Random Forest,
  and Gradient Boosting** (plus a naive mean baseline) with **5-fold cross-validation**, then
  tuned the strongest families with **`GridSearchCV`**. Target is `log1p(resolution_days)`,
  back-transformed with `expm1` so errors are reported in real days. Only intake-time features
  are used, so no future information leaks in.
- **Classification modeling (Notebook 4):** framed SLA breach as binary classification and
  compared **Logistic Regression, Random Forest, and Gradient Boosting** with 5-fold
  cross-validation on ROC-AUC, tuned via `GridSearchCV`, and evaluated with ROC/precision-recall
  curves and a confusion matrix.

#### Results

- **Resolution time is extremely right-skewed** — median **15.2 days** but a mean of
  **~126 days** and a tail past 1,700 days — which is why the target is modeled on a log
  scale.
- **Volume arrives unevenly** week to week with clear spikes, and the mix is dominated by
  the **COM (commercial)** segment, while **GOV/EDU** and certain offer families carry
  longer resolution tails — motivating a forward-looking volume forecast.
- **Regression — resolution effort (held-out test set, n = 1,323):**

  | Model | MAE (days) | RMSE (days) | R² (log scale) |
  |---|---|---|---|
  | Baseline (mean) | 112.8 | 264.1 | 0.00 |
  | Ridge | 106.6 | 249.1 | 0.28 |
  | ElasticNet (tuned) | 106.6 | 249.3 | 0.28 |
  | **Gradient Boosting (tuned)** | **90.6** | **220.8** | **0.48** |

  The non-linear **Gradient Boosting** model (selected on cross-validated MAE) beats the
  linear models on every metric — cutting typical error by **~16 days** and lifting the
  variance explained from R² 0.28 to **0.48**. The largest drivers of *longer* resolution are
  certain offer families (e.g. data-services / analytics offerings) and larger multi-line
  tickets; several other offer families and clouds are associated with *faster* resolution.

- **Classification — SLA breach at intake (held-out test set, n = 1,323; ~35% breach rate):**
  the tuned **Gradient Boosting classifier** reaches **ROC-AUC 0.90** and **PR-AUC 0.85**,
  correctly flagging **66% of tickets that actually breach** (recall) at **78% precision**.
  The **SLA window** (promised days between creation and due date) and a handful of offer
  families / segments are the strongest at-risk signals.

- **Evaluation metrics.** For regression, **MAE (days)** is the primary metric — interpretable
  units, robust to the heavy skew; **RMSE (days)** is tracked because it penalizes the large
  misses that correspond to SLA breaches; **R² (log scale)** gives a scale-free goodness-of-fit.
  For the imbalanced breach classifier, **ROC-AUC** is the primary (threshold-free) metric,
  with **recall** on the breach class watched closely because a missed at-risk ticket is the
  costly error.

#### Next steps

- Build the companion **time-series volume forecast** (weekly/monthly ticket counts via
  classical decomposition and ARMA) to complete the "how many are coming" half.
- **Operationalize** both models on the live intake queue so every incoming ticket carries a
  *predicted duration* (Notebook 3) and a *breach-risk flag* (Notebook 4); tune the alert
  threshold along the precision-recall curve with the operations team.
- Enrich features (requestor system behavior, historical assignee throughput) and validate
  on a full multi-year window rather than 2026 YTD.

#### Outline of project

- [Notebook 1 — Data Cleaning & Feature Engineering](notebooks/01_data_cleaning_and_feature_engineering.ipynb)
- [Notebook 2 — Exploratory Data Analysis](notebooks/02_exploratory_data_analysis.ipynb)
- [Notebook 3 — Modeling: Resolution-Time Regression](notebooks/03_modeling_regression.ipynb)
- [Notebook 4 — SLA-Breach Classification](notebooks/04_sla_breach_classification.ipynb)

Run the notebooks in order (1 → 4); Notebook 1 regenerates `data/cpt_clean.csv`, which the
others consume.

**Repository structure**

```
Capstone/
├── README.md                    # this report (nontechnical summary)
├── requirements.txt             # Python dependencies
├── extract_data.py              # Databricks → CSV extraction (with PII hashing)
├── data/
│   ├── cpt_active_tickets_2026.csv   # raw extract (input to Notebook 1)
│   └── cpt_clean.csv                 # cleaned dataset (output of Notebook 1)
└── notebooks/
    ├── 01_data_cleaning_and_feature_engineering.ipynb
    ├── 02_exploratory_data_analysis.ipynb
    ├── 03_modeling_regression.ipynb        # multi-model regression + GridSearchCV
    └── 04_sla_breach_classification.ipynb  # SLA-breach classifier
```

##### Contact and Further Information

Sravanthi Gandu — sravanthireddy.gandu@gmail.com
