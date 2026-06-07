library(dplyr)
library(ggplot2)
library(survival)

GOLD_PATH <- "/opt/delta_lake/gold"

cat("=== Retail Churn Model ===\n\n")

gold_df <- read.csv(file.path(GOLD_PATH, "customer_features.csv"))

cat("Customers:", nrow(gold_df),
    "| Churn rate:", round(mean(gold_df$is_churned) * 100, 1), "%\n\n")

feature_cols <- c(
    "recency_days", "frequency", "monetary_total",
    "avg_order_value", "avg_review_score", "avg_delivery_days"
)
gold_df <- gold_df |>
    mutate(
        is_churned = as.integer(is_churned),
        across(all_of(feature_cols), as.numeric),
        across(all_of(feature_cols),
               ~ ifelse(is.na(.), median(., na.rm = TRUE), .))
    )

# Train / test split
set.seed(42)
train_idx <- sample(seq_len(nrow(gold_df)), size = 0.8 * nrow(gold_df))
train     <- gold_df[ train_idx, ]
test      <- gold_df[-train_idx, ]

# Logistic regression
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

# Manual AUC-ROC (no pROC package needed)
ord        <- order(preds, decreasing = TRUE)
actual_ord <- test$is_churned[ord]
n_pos      <- sum(actual_ord == 1)
n_neg      <- sum(actual_ord == 0)
tp         <- cumsum(actual_ord == 1) / n_pos
fp         <- cumsum(actual_ord == 0) / n_neg
auc_val    <- sum(diff(fp) * (tp[-1] + tp[-length(tp)]) / 2)

cat("Accuracy:", round(accuracy * 100, 1), "%\n")
cat("AUC-ROC :", round(auc_val, 3), "\n\n")

# Save model summary
sink(file.path(GOLD_PATH, "model_summary.txt"))
cat("=== Logistic Regression — Churn Model ===\n\n")
print(summary(churn_model))
cat("\nAccuracy:", round(accuracy * 100, 1), "%\n")
cat("AUC-ROC :", round(auc_val, 3), "\n")
sink()

# Kaplan-Meier survival curve (ggplot2, no survminer)
cat("Fitting survival model...\n")
km_fit <- survfit(Surv(recency_days, is_churned) ~ 1, data = gold_df)
km_df  <- data.frame(
    time  = km_fit$time,
    surv  = km_fit$surv,
    upper = km_fit$upper,
    lower = km_fit$lower
)

surv_plot <- ggplot(km_df, aes(x = time, y = surv)) +
    geom_step(color = "steelblue", linewidth = 1) +
    geom_ribbon(aes(ymin = lower, ymax = upper),
                alpha = 0.15, fill = "steelblue") +
    labs(
        title = "Customer Retention — Kaplan-Meier Curve",
        x     = "Days Since Last Purchase",
        y     = "Retention Probability",
    ) +
    theme_minimal()
ggsave(file.path(GOLD_PATH, "survival_curve.png"),
       plot = surv_plot, width = 10, height = 6, dpi = 150)

# RFM distribution by churn status
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
ggsave(file.path(GOLD_PATH, "rfm_distribution.png"),
       plot = rfm_plot, width = 10, height = 6, dpi = 150)

cat("Done. Outputs saved to", GOLD_PATH, "\n")
cat("  model_summary.txt\n  survival_curve.png\n  rfm_distribution.png\n")