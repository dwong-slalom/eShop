# Pricing Rules Configuration Guide

## Overview

The eShop system supports dynamic pricing through a declarative rules engine. Business teams can configure pricing strategies (volume discounts, category discounts, customer tier benefits) without requiring code changes or full system redeploy—only a server restart is needed.

Pricing rules are defined in a JSON configuration file and loaded at application startup. Rules are evaluated in **first-match-wins** order: the first rule whose conditions match is applied, and no further rules are evaluated for that item.

---

## Rule File Location

**File:** `src/Catalog.API/config/pricing-rules.json`

Rules are loaded into the Basket API at startup. After editing the config file, restart the Basket API service for changes to take effect.

---

## Rule Structure

Each pricing rule follows this JSON structure:

```json
{
  "name": "unique_rule_identifier",
  "description": "Human-readable explanation of the rule",
  "condition": {
    "type": "quantity | category | customer_tier | product_tag",
    "operator": "== | != | >= | > | <= | < | contains | not_contains",
    "value": "string_or_number"
  },
  "discountPercent": 10
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Unique identifier for the rule (snake_case recommended). Used for logging and debugging. |
| `description` | string | Yes | Human-readable explanation of when and why this rule applies. |
| `condition.type` | enum | Yes | The attribute to evaluate: `quantity`, `category`, `customer_tier`, or `product_tag`. |
| `condition.operator` | enum | Yes | Comparison operator. See [Operators](#operators) below. |
| `condition.value` | string/number | Yes | The value to compare against. For numeric types (quantity), use a string representation of the number. |
| `discountPercent` | number | Yes | Discount amount in percentage (0–100). Applied to the item's current price. |

---

## Condition Types

### 1. Quantity Conditions

**Type:** `quantity`

Matches based on the number of units of the product in the basket.

**Valid Operators:** `>=`, `>`, `<=`, `<`, `==`

**Example:** Give 10% off when customers buy 5 or more units:
```json
{
  "name": "volume_discount_5",
  "description": "10% off for bulk orders (5+ units)",
  "condition": {
    "type": "quantity",
    "operator": ">=",
    "value": "5"
  },
  "discountPercent": 10
}
```

### 2. Category Conditions

**Type:** `category`

Matches based on the product category. The category is associated with the product in the catalog.

**Valid Operators:** `==`, `!=`

**Example:** Offer 5% off all electronics:
```json
{
  "name": "electronics_discount",
  "description": "5% off all electronics",
  "condition": {
    "type": "category",
    "operator": "==",
    "value": "electronics"
  },
  "discountPercent": 5
}
```

### 3. Customer Tier Conditions

**Type:** `customer_tier`

Matches based on the customer's tier level (e.g., `standard`, `silver`, `gold`, `premium`).

**Valid Operators:** `==`, `!=`

**Example:** Premium customers get 20% off on all purchases:
```json
{
  "name": "premium_tier_discount",
  "description": "20% discount for premium tier customers",
  "condition": {
    "type": "customer_tier",
    "operator": "==",
    "value": "premium"
  },
  "discountPercent": 20
}
```

### 4. Product Tag Conditions

**Type:** `product_tag`

Matches based on tags assigned to products in the catalog (e.g., `sale`, `clearance`, `new-arrival`).

**Valid Operators:** `contains`, `not_contains`

**Example:** Give 15% off all products tagged with `clearance`:
```json
{
  "name": "clearance_discount",
  "description": "15% off clearance items",
  "condition": {
    "type": "product_tag",
    "operator": "contains",
    "value": "clearance"
  },
  "discountPercent": 15
}
```

---

## Operators

| Operator | Type | Use Case |
|----------|------|----------|
| `==` | equality | Exact match (quantity, category, customer_tier) |
| `!=` | inequality | Exclusion (category, customer_tier) |
| `>=` | greater-or-equal | Quantity thresholds; e.g., "5 or more" |
| `>` | greater-than | Quantity thresholds; e.g., "more than 5" (= 6+) |
| `<=` | less-or-equal | Quantity caps; e.g., "up to 10" |
| `<` | less-than | Quantity caps; e.g., "fewer than 10" (= 0–9) |
| `contains` | substring | Product tags; matches if value is present in tag list |
| `not_contains` | substring | Product tags; matches if value is absent from tag list |

---

## File Format

The `pricing-rules.json` file wraps rules in a `pricing.rules` array:

```json
{
  "pricing": {
    "rules": [
      { rule 1 },
      { rule 2 },
      ...
    ]
  }
}
```

---

## Complete Example

```json
{
  "pricing": {
    "rules": [
      {
        "name": "volume_5_units",
        "description": "10% off when buying 5+ units",
        "condition": {
          "type": "quantity",
          "operator": ">=",
          "value": "5"
        },
        "discountPercent": 10
      },
      {
        "name": "volume_10_units",
        "description": "15% off when buying 10+ units",
        "condition": {
          "type": "quantity",
          "operator": ">=",
          "value": "10"
        },
        "discountPercent": 15
      },
      {
        "name": "electronics_5_off",
        "description": "5% off all electronics",
        "condition": {
          "type": "category",
          "operator": "==",
          "value": "electronics"
        },
        "discountPercent": 5
      },
      {
        "name": "premium_customer",
        "description": "20% discount for premium tier customers",
        "condition": {
          "type": "customer_tier",
          "operator": "==",
          "value": "premium"
        },
        "discountPercent": 20
      },
      {
        "name": "clearance_items",
        "description": "15% off clearance-tagged items",
        "condition": {
          "type": "product_tag",
          "operator": "contains",
          "value": "clearance"
        },
        "discountPercent": 15
      }
    ]
  }
}
```

---

## Rule Evaluation Behavior

### First-Match-Wins Strategy

Rules are evaluated **in order**. The first rule whose condition matches is applied, and evaluation stops immediately. Subsequent rules are not evaluated.

**Example:**

Given these rules (in this order):
1. Volume discount: 5+ units → 10% off
2. Electronics category → 5% off

When a customer adds 5+ units of electronics:
- Rule 1 matches (quantity >= 5)
- **10% discount is applied**
- Rule 2 is never evaluated
- Customer gets 10%, not 5%

**Important:** Order matters. Place more specific/valuable discounts before general ones to ensure they take priority.

### No Match

If no rule conditions are satisfied, the item receives 0% discount (regular price).

### Discount Application

- Discounts are applied to individual items in the basket
- Each item is evaluated independently against all rules
- Different items in the same basket can receive different discounts

---

## Validation Rules

When editing `pricing-rules.json`, ensure:

1. **Valid JSON syntax** — Validate with a JSON linter before saving.
2. **Unique rule names** — Each rule must have a distinct `name`.
3. **Discount range** — `discountPercent` must be 0–100.
4. **Operator/type pairing** — Use only valid operators for each condition type:
   - `quantity`: `>=`, `>`, `<=`, `<`, `==`
   - `category`: `==`, `!=`
   - `customer_tier`: `==`, `!=`
   - `product_tag`: `contains`, `not_contains`
5. **Value types** — For `quantity`, use a string representation of a number.

---

## Deployment & Restart

### To Apply Rule Changes

1. Edit `src/Catalog.API/config/pricing-rules.json`
2. Commit and push to the repository (or update the file via your configuration management system)
3. **Restart the Basket API service**

The pricing engine reads the config file once at startup. Changes take effect immediately upon service restart.

### No Runtime Reloading

The system does **not** hot-reload pricing rules. A server restart is required for changes to take effect.

---

## Troubleshooting

### Rules Not Applied

- ✓ Verify the Basket API was restarted after editing the config file.
- ✓ Check the JSON file for syntax errors (use an online JSON validator).
- ✓ Confirm rule conditions are written correctly (operators, value types).

### Wrong Discount Applied

- ✓ Verify rule order. The first matching rule wins.
- ✓ Check condition types and operators are valid.
- ✓ Ensure customer tier values in the rule match the tier values in your customer database.

### Performance Impact

- ✓ Rule evaluation is fast (< 1ms per item).
- ✓ Evaluation happens once per basket update.
- ✓ No external service calls required (rules are in-memory).

---

## Future Enhancements

Planned features (not yet implemented):

- **Hot reloading:** Apply rule changes without restarting services.
- **Promo codes:** Discount codes that customers enter at checkout.
- **Time-based rules:** Discounts that start/end on specific dates.
- **Shipping discounts:** Rule-based shipping cost adjustments.
- **Complex conditions:** Boolean AND/OR logic across multiple conditions.
- **Admin UI:** Web interface to create/edit rules without touching JSON.

---

## Support

For questions or issues with pricing rules:
- Review this guide's [Complete Example](#complete-example) section.
- Check the `docs/superpowers/plans/2026-11-03-pricing-rules-engine.md` file for technical implementation details.
- See [Catalog.API pricing engine implementation](../src/Catalog.API/Services/Pricing/PricingRulesEngine.cs).
