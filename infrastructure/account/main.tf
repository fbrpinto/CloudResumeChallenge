# -------------------------------------- Account --------------------------------------- #
# Account-wide cost guardrails: daily budget, cost anomaly alerts and the billing alarm.
# Applied from a laptop after the backend stack (it uses the backend's us-east-1 SNS topic);
# CI never touches this stack.
#
# The monthly budget that triggers the kill switch stays outside Terraform until the kill
# switch is replaced.
terraform {
  backend "s3" {
    bucket       = "crc-fbrpinto-terraform-state"
    key          = "account/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
  }
}

# ------------------------------------- Providers -------------------------------------- #
# Billing metrics and cost anomaly alerts live in us-east-1
provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# Created by the backend stack; delivers to email and ntfy
data "aws_sns_topic" "alerts" {
  name = var.sns_topic_name
}


# --------------------------------------- Budgets -------------------------------------- #
# Budgets without actions are free. Data refreshes a few times a day.
resource "aws_budgets_budget" "daily" {
  name         = "crc-fbrpinto-daily-budget"
  budget_type  = "COST"
  limit_amount = var.daily_budget
  limit_unit   = "USD"
  time_unit    = "DAILY"

  # Same cost types as the monthly budget
  cost_types {
    include_credit = false
    include_refund = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notification_email]
  }
}


# ------------------------------- Cost Anomaly Detection ------------------------------- #
# Free. Each anomaly is reported once (plus updates if its impact is revised).
import {
  to = aws_ce_anomaly_monitor.services
  id = "arn:aws:ce::${data.aws_caller_identity.current.account_id}:anomalymonitor/bfc4329a-2804-401c-9b0d-7f80cb2f8400"
}

resource "aws_ce_anomaly_monitor" "services" {
  name              = "Default-Services-Monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

# Daily email digest
import {
  to = aws_ce_anomaly_subscription.daily_email
  id = "arn:aws:ce::${data.aws_caller_identity.current.account_id}:anomalysubscription/3081e661-7b82-48ba-9c2d-6e860df91e8e"
}

resource "aws_ce_anomaly_subscription" "daily_email" {
  name             = "Default-Services-Subscription"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  subscriber {
    type    = "EMAIL"
    address = var.notification_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold)]
    }
  }
}

# Sent as soon as the anomaly is found, to ntfy (and email) through SNS
resource "aws_ce_anomaly_subscription" "immediate_sns" {
  name             = "crc-fbrpinto-anomaly-immediate"
  frequency        = "IMMEDIATE"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  subscriber {
    type    = "SNS"
    address = data.aws_sns_topic.alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold)]
    }
  }
}


# ------------------------------------ Billing Alarm ----------------------------------- #
# Needs "Receive CloudWatch billing alerts" ticked in Billing preferences.
# Free: standard resolution (period of 60 s or more) and the metric is listed directly.
# The description is the label sent to ntfy, so keep it short and free of names.
resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  alarm_name          = "crc-fbrpinto-estimated-charges"
  alarm_description   = "Estimated bill this month (USD)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600
  statistic           = "Maximum"
  threshold           = var.billing_alarm_threshold

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [data.aws_sns_topic.alerts.arn]
  ok_actions    = [data.aws_sns_topic.alerts.arn]
}
