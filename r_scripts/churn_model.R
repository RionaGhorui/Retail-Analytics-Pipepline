library(arrow)
library(dplyr)
library(ggplot2)
library(survival)
library(survminer)
library(pROC)

GOLD_PATH <- "/opt/delta_lake/gold"

cat("=== Retail Churn Model ===\n\n")

cat("Reading Gold layer...\n")
gold_df <- open_dataset(
    file.path(GOLD_PATH, "customer_features_parquet"),
    format = "parquet"
) |> collect()

cat("Customers:", nrow(gold_df),
    "| Churn rate:", round(mean(gold_df$is_churned) * 100, 1), "%\n\n")

feature_cols <- c(
    "recency_days", "frequency", "monetary_total",
    "avg_order_value", "avg_review_score", "avg_delivery_days"
)
gold_df <- gold_df |>
    mutate(
        is_churned   = as.integer(is_churned),
        across(all_of(feature_cols), as.numeric),
        across(all_of(feature_cols),
               ~ ifelse(is.na(.), median(., na.rm = TRUE), .))
    )

set.seed(42)
train_idx <- sample(seq_len(nrow(gold_df)), size = 0.8 * nrow(gold_df))
train     <- gold_df[ train_idx, ]
test      <- gold_df[-train_idx, ]

cat("Fitting logistic regression...\n")
churn_model <- glm(
    is_churned ~ recency_days + frequency + monetary_total +
                 avg_order_value + avg_review_score + avg_delivery_days,
    data   = train,
    family = binomial(link = "logit"),
)

preds      <- predict(churn_model, newdata = test, type = "response")
pred_class <- ifelse(preds > 0.5, 1, 0)
accuracy   <- mean(pred_class == test$is_churned)
roc_obj    <- roc(test$is_churned, preds, quiet = TRUE)

cat("Accuracy :", round(accuracy * 100, 1), "%\n")
cat("AUC-ROC  :", round(as.numeric(auc(roc_obj)), 3), "\n\n")

sink(file.path(GOLD_PATH, "model_summary.txt"))
cat("=== Logistic Regression — Churn Model ===\n\n")
print(summary(churn_model))
cat("\n--- Evaluation on held-out test set ---\n")
cat("Accuracy :", round(accuracy * 100, 1), "%\n")
cat("AUC-ROC  :", round(as.numeric(auc(roc_obj)), 3), "\n")
sink()

cat("Fitting survival model...\n")
surv_obj <- Surv(time = gold_df$recency_days, event = gold_df$is_churned)
km_fit   <- survfit(surv_obj ~ 1, data = gold_df)

surv_plot <- ggsurvplot(
    km_fit,
    data        = gold_df,
    xlab        = "Days Since Last Purchase",
    ylab        = "Retention Probability",
    title       = "Customer Retention — Kaplan-Meier Curve",
    conf.int    = TRUE,
    ggtheme     = theme_minimal(),
    palette     = "steelblue",
)
ggsave(
    file.path(GOLD_PATH, "survival_curve.png"),
    plot   = surv_plot$plot,
    width  = 10,
    height = 6,
    dpi    = 150,
)

rfm_plot <- ggplot(gold_df, aes(x = recency_days, fill = factor(is_churned))) +
    geom_histogram(bins = 40, alpha = 0.7, position = "identity") +
    scale_fill_manual(
        values = c("steelblue", "tomato"),
        labels = c("Active", "Churned"),
    ) +
    labs(
        title = "Recency Distribution by Churn Status",
        x     = "Days Since Last Purchase",
        y     = "Customer Count",
        fill  = "",
    ) +
    theme_minimal()
ggsave(
    file.path(GOLD_PATH, "rfm_distribution.png"),
    plot   = rfm_plot,
    width  = 10,
    height = 6,
    dpi    = 150,
)

cat("\nDone. Outputs written to", GOLD_PATH, "\n")
cat("  model_summary.txt\n")
cat("  survival_curve.png\n")
cat("  rfm_distribution.png\n")
