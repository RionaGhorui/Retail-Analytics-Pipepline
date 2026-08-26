Retail Customer Churn & Retention Analysis
---
### Read about the project
#### 🔗 [Project Landing Page](https://retailanalyticsdashboard.vercel.app/)
#### Tech Stack:  Python, R, Delta Lake, Apache Spark, Apache Airflow, Docker
---
### Project Workflow
(Made by me on LucidCharts)

![workflow](/display/assets/Technical_flow.png)

## OUTPUTS AND EXPLANATION
### 1. This shows how customer retention drops over time. 100% of customers are active at the start, but by day 300 they have lost half, and by day 650 almost no one remains, meaning most customers churn within 10 to 22 months of their last purchase.


![workflow](/display/assets/retention_curve.png)

---

### 2. This shows active and churned customers separated by how recently they purchased. Active customers cluster tightly before 180 days, churned customers spread far beyond it, confirming that recency is the strongest signal for identifying customers at risk of leaving.

![workflow](/display/assets/distribution.png)

---
## Screenshots of processing
![workflow](/display/assets/docker.png)
![workflow](/display/assets/airflow_home.png)
![workflow](/display/assets/airflow_graph.png)

