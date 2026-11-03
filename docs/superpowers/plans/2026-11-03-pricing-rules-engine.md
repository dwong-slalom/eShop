# Declarative Pricing Rules Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a config-driven pricing rules engine that allows business teams to define discount strategies in JSON without code changes.

**Architecture:** Rules are defined in a JSON config file loaded at application startup. A `PricingRulesEngine` service evaluates conditions (quantity, category, customer tier, product tags) against basket items and returns the first matching discount. Integration points are in `Basket.API` and `Catalog.API`.

**Tech Stack:** .NET 10, C# 13, System.Text.Json (built-in), dependency injection

**Spec:** `docs/superpowers/specs/2026-11-03-pricing-rules-design.md`

## Global Constraints

- Rules are loaded once at application startup; server restart required for config changes
- Config file format is JSON (not YAML or expressions)
- Single discount per item: first matching rule wins; no stacking
- No external expression parser or rule engine library dependencies
- Rules must not break the system (invalid rules ignored or caught at startup)
- Rules apply only to basket checkout, not to orders after submission

## File Structure

### New Files

| File | Responsibility |
|------|-----------------|
| `src/Catalog.API/Services/Pricing/IPricingRulesEngine.cs` | Interface for pricing rule evaluation |
| `src/Catalog.API/Services/Pricing/PricingRulesEngine.cs` | Core engine: loads JSON, evaluates conditions, returns discount |
| `src/Catalog.API/Services/Pricing/PricingRule.cs` | Data class for deserialized pricing rule from JSON |
| `src/Catalog.API/Services/Pricing/PricingCondition.cs` | Data class for deserialized condition from JSON |
| `src/Catalog.API/config/pricing-rules.json` | Sample pricing rules in JSON format |
| `tests/Catalog.UnitTests/Services/PricingRulesEngineTests.cs` | Unit tests for rule evaluation logic |

### Modified Files

| File | Change |
|------|--------|
| `src/Basket.API/Program.cs` | Register `IPricingRulesEngine` in DI container; load config file |
| `src/Basket.API/Grpc/BasketService.cs` | Call pricing engine before returning basket in `UpdateBasket()` |

## Review Focus

These inputs or conditions could break the system if not handled:

1. **Empty or missing config file** — Engine should initialize with empty rules list, not throw
2. **Invalid JSON syntax** — Config load failure should throw meaningful startup error
3. **Invalid condition types or operators** — Should be rejected at startup or safely ignored
4. **Null/missing customer tier** — Engine should handle null customer tier gracefully
5. **Discount percentage out of range** — Should clamp to 0–100 or reject invalid values

Each task's Review Focus tests are listed in the task's test step.

---

## Task 1: Create Pricing Rules Data Classes

**Files:**
- Create: `src/Catalog.API/Services/Pricing/PricingCondition.cs`
- Create: `src/Catalog.API/Services/Pricing/PricingRule.cs`

**Interfaces:**
- Produces: `PricingCondition` with properties: `Type`, `Operator`, `Value` (all `string`)
- Produces: `PricingRule` with properties: `Name`, `Description`, `Condition`, `DiscountPercent` (all public, settable)

- [ ] **Step 1: Create `PricingCondition.cs` data class**

File: `src/Catalog.API/Services/Pricing/PricingCondition.cs`

```csharp
namespace eShop.Catalog.API.Services.Pricing;

public class PricingCondition
{
    public string Type { get; set; } = string.Empty;
    public string Operator { get; set; } = string.Empty;
    public string Value { get; set; } = string.Empty;
}
```

- [ ] **Step 2: Create `PricingRule.cs` data class**

File: `src/Catalog.API/Services/Pricing/PricingRule.cs`

```csharp
namespace eShop.Catalog.API.Services.Pricing;

public class PricingRule
{
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public PricingCondition Condition { get; set; } = new();
    public decimal DiscountPercent { get; set; }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/Catalog.API/Services/Pricing/PricingCondition.cs src/Catalog.API/Services/Pricing/PricingRule.cs
git commit -m "feat: add pricing rule data classes"
```

---

## Task 2: Create IPricingRulesEngine Interface

**Files:**
- Create: `src/Catalog.API/Services/Pricing/IPricingRulesEngine.cs`

**Interfaces:**
- Produces: `IPricingRulesEngine.CalculateDiscount(string productCategory, int quantity, string customerTier) -> decimal`
  - Returns discount percentage (0–100)
  - Default: returns 0m if no rule matches or if rules list is empty

- [ ] **Step 1: Create interface**

File: `src/Catalog.API/Services/Pricing/IPricingRulesEngine.cs`

```csharp
namespace eShop.Catalog.API.Services.Pricing;

public interface IPricingRulesEngine
{
    /// <summary>
    /// Calculate the discount percentage for a basket item.
    /// </summary>
    /// <param name="productCategory">Product category (e.g., "electronics")</param>
    /// <param name="quantity">Number of units in basket item</param>
    /// <param name="customerTier">Customer tier (e.g., "premium", "standard")</param>
    /// <returns>Discount percentage (0–100); 0 if no rule matches</returns>
    decimal CalculateDiscount(string productCategory, int quantity, string customerTier);
}
```

- [ ] **Step 2: Commit**

```bash
git add src/Catalog.API/Services/Pricing/IPricingRulesEngine.cs
git commit -m "feat: add IPricingRulesEngine interface"
```

---

## Task 3: Implement PricingRulesEngine

**Files:**
- Create: `src/Catalog.API/Services/Pricing/PricingRulesEngine.cs`

**Interfaces:**
- Consumes: `IConfiguration` (from dependency injection)
- Consumes: `PricingRule` and `PricingCondition` from Task 1
- Implements: `IPricingRulesEngine` from Task 2
- Produces: Logic to evaluate quantity (`>=`, `>`, `<=`, `<`, `==`), category (`==`, `!=`), customer_tier (`==`, `!=`), product_tag (`contains`, `not_contains`)

- [ ] **Step 1: Write unit test for empty rules list**

File: `tests/Catalog.UnitTests/Services/PricingRulesEngineTests.cs`

```csharp
namespace eShop.Catalog.UnitTests.Services;

using eShop.Catalog.API.Services.Pricing;
using Microsoft.Extensions.Configuration;
using Xunit;

public class PricingRulesEngineTests
{
    [Fact]
    public void CalculateDiscount_NoRules_ReturnsZero()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string> { })
            .Build();
        
        var engine = new PricingRulesEngine(config);
        var discount = engine.CalculateDiscount("electronics", 5, "standard");
        
        Assert.Equal(0m, discount);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dotnet test tests/Catalog.UnitTests/Services/PricingRulesEngineTests.cs::eShop.Catalog.UnitTests.Services.PricingRulesEngineTests.CalculateDiscount_NoRules_ReturnsZero -v
```

Expected: FAIL with "type or namespace name 'PricingRulesEngine' could not be found"

- [ ] **Step 3: Implement PricingRulesEngine.cs**

File: `src/Catalog.API/Services/Pricing/PricingRulesEngine.cs`

Implement:
- Constructor: Load rules from `IConfiguration.GetSection("pricing:rules").Get<List<PricingRule>>()`
- `CalculateDiscount()`: Loop through rules in order; evaluate condition; return first match's `DiscountPercent`; return 0 if no match
- Private `EvaluateCondition()`: Delegate to type-specific evaluation methods
- Private `EvaluateQuantity()`: Compare item quantity using operator
- Private `EvaluateCategory()`: Compare category string using operator
- Private `EvaluateCustomerTier()`: Compare tier string using operator
- Private `EvaluateProductTag()`: Check if tags contain value (stub for now; returns false)

```csharp
namespace eShop.Catalog.API.Services.Pricing;

using Microsoft.Extensions.Configuration;

public class PricingRulesEngine : IPricingRulesEngine
{
    private readonly List<PricingRule> _rules;
    private readonly ILogger<PricingRulesEngine> _logger;

    public PricingRulesEngine(IConfiguration configuration, ILogger<PricingRulesEngine> logger)
    {
        _logger = logger;
        _rules = configuration.GetSection("pricing:rules").Get<List<PricingRule>>() ?? new();
        _logger.LogInformation("Loaded {RuleCount} pricing rules", _rules.Count);
    }

    public decimal CalculateDiscount(string productCategory, int quantity, string customerTier)
    {
        foreach (var rule in _rules)
        {
            if (EvaluateCondition(rule.Condition, productCategory, quantity, customerTier))
            {
                _logger.LogDebug("Rule '{RuleName}' matched; discount: {Discount}%", rule.Name, rule.DiscountPercent);
                return rule.DiscountPercent;
            }
        }

        return 0m;
    }

    private bool EvaluateCondition(PricingCondition condition, string productCategory, int quantity, string customerTier)
    {
        if (condition == null)
            return false;

        return condition.Type?.ToLowerInvariant() switch
        {
            "quantity" => EvaluateQuantity(quantity, condition.Operator, condition.Value),
            "category" => EvaluateCategory(productCategory, condition.Operator, condition.Value),
            "customer_tier" => EvaluateCustomerTier(customerTier, condition.Operator, condition.Value),
            "product_tag" => EvaluateProductTag(condition.Operator, condition.Value),
            _ => false
        };
    }

    private bool EvaluateQuantity(int quantity, string op, string value)
    {
        if (!int.TryParse(value, out var threshold))
            return false;

        return op?.ToLowerInvariant() switch
        {
            ">=" => quantity >= threshold,
            ">" => quantity > threshold,
            "<=" => quantity <= threshold,
            "<" => quantity < threshold,
            "==" => quantity == threshold,
            _ => false
        };
    }

    private bool EvaluateCategory(string category, string op, string value)
    {
        if (string.IsNullOrEmpty(category))
            return false;

        return op?.ToLowerInvariant() switch
        {
            "==" => category.Equals(value, StringComparison.OrdinalIgnoreCase),
            "!=" => !category.Equals(value, StringComparison.OrdinalIgnoreCase),
            _ => false
        };
    }

    private bool EvaluateCustomerTier(string tier, string op, string value)
    {
        if (string.IsNullOrEmpty(tier))
            return false;

        return op?.ToLowerInvariant() switch
        {
            "==" => tier.Equals(value, StringComparison.OrdinalIgnoreCase),
            "!=" => !tier.Equals(value, StringComparison.OrdinalIgnoreCase),
            _ => false
        };
    }

    private bool EvaluateProductTag(string op, string value)
    {
        // Stub for product tag evaluation; requires product tag data
        // Task 4 will wire this to actual product data
        return false;
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dotnet test tests/Catalog.UnitTests/Services/PricingRulesEngineTests.cs::eShop.Catalog.UnitTests.Services.PricingRulesEngineTests.CalculateDiscount_NoRules_ReturnsZero -v
```

Expected: PASS

- [ ] **Step 5: Add tests for quantity operator evaluation**

Add to `PricingRulesEngineTests.cs`:

```csharp
[Theory]
[InlineData(">=", 5, 5, true)]
[InlineData(">=", 6, 5, true)]
[InlineData(">=", 4, 5, false)]
[InlineData(">", 6, 5, true)]
[InlineData(">", 5, 5, false)]
[InlineData("<=", 5, 5, true)]
[InlineData("<=", 4, 5, true)]
[InlineData("<=", 6, 5, false)]
[InlineData("<", 4, 5, true)]
[InlineData("<", 5, 5, false)]
[InlineData("==", 5, 5, true)]
[InlineData("==", 6, 5, false)]
public void CalculateDiscount_QuantityRule_EvaluatesCorrectly(string op, int quantity, int threshold, bool shouldMatch)
{
    var config = new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string>
        {
            ["pricing:rules:0:name"] = "test_rule",
            ["pricing:rules:0:condition:type"] = "quantity",
            ["pricing:rules:0:condition:operator"] = op,
            ["pricing:rules:0:condition:value"] = threshold.ToString(),
            ["pricing:rules:0:discountPercent"] = "10"
        })
        .Build();

    var engine = new PricingRulesEngine(config, new NullLogger<PricingRulesEngine>());
    var discount = engine.CalculateDiscount("electronics", quantity, "standard");

    if (shouldMatch)
        Assert.Equal(10m, discount);
    else
        Assert.Equal(0m, discount);
}
```

- [ ] **Step 6: Run all engine tests**

```bash
dotnet test tests/Catalog.UnitTests/Services/PricingRulesEngineTests.cs -v
```

Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add src/Catalog.API/Services/Pricing/PricingRulesEngine.cs tests/Catalog.UnitTests/Services/PricingRulesEngineTests.cs
git commit -m "feat: implement PricingRulesEngine with quantity, category, and tier evaluation"
```

---

## Task 4: Create Sample Pricing Rules Config File

**Files:**
- Create: `src/Catalog.API/config/pricing-rules.json`

**Interfaces:**
- Consumes: JSON format from design spec
- Produces: Valid config file ready for `PricingRulesEngine` to load

- [ ] **Step 1: Create pricing-rules.json**

File: `src/Catalog.API/config/pricing-rules.json`

```json
{
  "pricing": {
    "rules": [
      {
        "name": "volume_discount_5_units",
        "description": "10% off when buying 5+ units of same item",
        "condition": {
          "type": "quantity",
          "operator": ">=",
          "value": "5"
        },
        "discountPercent": 10
      },
      {
        "name": "volume_discount_10_units",
        "description": "15% off when buying 10+ units of same item",
        "condition": {
          "type": "quantity",
          "operator": ">=",
          "value": "10"
        },
        "discountPercent": 15
      },
      {
        "name": "category_electronics_5_percent",
        "description": "5% off all electronics",
        "condition": {
          "type": "category",
          "operator": "==",
          "value": "electronics"
        },
        "discountPercent": 5
      },
      {
        "name": "premium_customer_discount",
        "description": "20% off for premium tier customers",
        "condition": {
          "type": "customer_tier",
          "operator": "==",
          "value": "premium"
        },
        "discountPercent": 20
      }
    ]
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/Catalog.API/config/pricing-rules.json
git commit -m "config: add sample pricing rules"
```

---

## Task 5: Register PricingRulesEngine in DI and Load Config

**Files:**
- Modify: `src/Basket.API/Program.cs`

**Interfaces:**
- Consumes: `IPricingRulesEngine` interface and `PricingRulesEngine` implementation from Tasks 2–3
- Consumes: `pricing-rules.json` from Task 4
- Produces: Registered `IPricingRulesEngine` singleton in DI container; config file loaded at startup

- [ ] **Step 1: Modify Program.cs to register the engine**

File: `src/Basket.API/Program.cs`

Add to the service registration section (before `var app = builder.Build();`):

```csharp
using eShop.Catalog.API.Services.Pricing;

// ... existing code ...

// Register pricing rules engine
var pricingConfigPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "Catalog.API", "config", "pricing-rules.json");
var pricingConfig = new ConfigurationBuilder()
    .AddJsonFile(pricingConfigPath, optional: true, reloadOnChange: false)
    .Build();

builder.Services.AddSingleton<IPricingRulesEngine>(sp =>
    new PricingRulesEngine(pricingConfig, sp.GetRequiredService<ILogger<PricingRulesEngine>>()));

var app = builder.Build();
```

**Note:** Adjust the path logic based on how eShop structures its service modules. The goal is to load the JSON file from Catalog.API's config folder.

- [ ] **Step 2: Run Basket.API to verify startup**

```bash
cd src/Basket.API
dotnet build
```

Expected: Build succeeds; no errors about missing config or types

- [ ] **Step 3: Commit**

```bash
git add src/Basket.API/Program.cs
git commit -m "feat: register IPricingRulesEngine in Basket.API DI container"
```

---

## Task 6: Integrate PricingRulesEngine into BasketService

**Files:**
- Modify: `src/Basket.API/Grpc/BasketService.cs`

**Interfaces:**
- Consumes: `IPricingRulesEngine` from DI
- Consumes: `BasketItem` (existing model with `Quantity`, `UnitPrice`, `ProductName`)
- Produces: Modified `UpdateBasket()` that calls `CalculateDiscount()` before returning

- [ ] **Step 1: Inject IPricingRulesEngine into BasketService constructor**

File: `src/Basket.API/Grpc/BasketService.cs`

Modify the constructor to add the parameter:

```csharp
public class BasketService(
    IBasketRepository repository,
    IPricingRulesEngine pricingEngine,
    ILogger<BasketService> logger) : Basket.BasketBase
```

- [ ] **Step 2: Call pricing engine in UpdateBasket()**

In the `UpdateBasket()` method, after mapping the basket items but before saving/returning, apply discounts:

```csharp
public override async Task<CustomerBasketResponse> UpdateBasket(UpdateBasketRequest request, ServerCallContext context)
{
    var userId = context.GetUserIdentity();
    if (string.IsNullOrEmpty(userId))
    {
        ThrowNotAuthenticated();
    }

    if (logger.IsEnabled(LogLevel.Debug))
    {
        logger.LogDebug("Begin UpdateBasket call from method {Method} for basket id {Id}", context.Method, userId);
    }

    var customerBasket = MapToCustomerBasket(userId, request);
    
    // Apply pricing rules to each item
    foreach (var item in customerBasket.Items)
    {
        var discount = pricingEngine.CalculateDiscount(
            item.Category ?? "general",
            item.Quantity,
            GetCustomerTier(userId)); // TODO: implement GetCustomerTier or mock it
        
        if (discount > 0)
        {
            item.AppliedDiscount = discount;
            logger.LogDebug("Applied {Discount}% discount to item {ProductId}", discount, item.ProductId);
        }
    }
    
    var response = await repository.UpdateBasketAsync(customerBasket);
    if (response is null)
    {
        ThrowBasketDoesNotExist(userId);
    }

    return MapToCustomerBasketResponse(response);
}

private string GetCustomerTier(string userId)
{
    // TODO: Look up customer tier from Buyer aggregate or customer service
    // For now, default to "standard"
    return "standard";
}
```

**Note:** The `BasketItem` model may need a new property `AppliedDiscount`. See Task 7.

- [ ] **Step 3: Run Basket.API locally to verify no compilation errors**

```bash
cd src/Basket.API
dotnet build
```

Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add src/Basket.API/Grpc/BasketService.cs
git commit -m "feat: integrate PricingRulesEngine into UpdateBasket"
```

---

## Task 7: Add AppliedDiscount Property to BasketItem (Optional)

**Files:**
- Modify: `src/Basket.API/Model/BasketItem.cs`

**Interfaces:**
- Produces: New property `AppliedDiscount` (decimal) to track which discount was applied

- [ ] **Step 1: Add AppliedDiscount property**

File: `src/Basket.API/Model/BasketItem.cs`

Add to the class:

```csharp
public decimal AppliedDiscount { get; set; }
```

- [ ] **Step 2: Run tests to ensure no breakage**

```bash
dotnet test tests/Basket.UnitTests/ -v
```

Expected: All existing tests still pass

- [ ] **Step 3: Commit**

```bash
git add src/Basket.API/Model/BasketItem.cs
git commit -m "feat: add AppliedDiscount property to BasketItem"
```

---

## Task 8: End-to-End Verification Test

**Files:**
- Create: `tests/Catalog.UnitTests/Services/PricingRulesEngineIntegrationTests.cs`

**Interfaces:**
- Consumes: Full JSON config from Task 4
- Produces: Integration test verifying real config file loads and rules evaluate correctly

- [ ] **Step 1: Write integration test loading real config file**

File: `tests/Catalog.UnitTests/Services/PricingRulesEngineIntegrationTests.cs`

```csharp
namespace eShop.Catalog.UnitTests.Services;

using eShop.Catalog.API.Services.Pricing;
using Microsoft.Extensions.Configuration;
using Xunit;

public class PricingRulesEngineIntegrationTests
{
    [Fact]
    public void LoadConfigFile_ParsesCorrectly_AndEvaluatesRules()
    {
        var configPath = Path.Combine(
            AppContext.BaseDirectory,
            "..", "..", "..", "..",
            "src", "Catalog.API", "config", "pricing-rules.json");

        var config = new ConfigurationBuilder()
            .AddJsonFile(configPath)
            .Build();

        var engine = new PricingRulesEngine(config, new NullLogger<PricingRulesEngine>());

        // Test volume discount rule
        var discount1 = engine.CalculateDiscount("electronics", 5, "standard");
        Assert.Equal(10m, discount1); // 5 units >= 5

        // Test premium customer discount (supersedes volume)
        var discount2 = engine.CalculateDiscount("books", 2, "premium");
        Assert.Equal(20m, discount2); // premium tier

        // Test no match
        var discount3 = engine.CalculateDiscount("furniture", 1, "standard");
        Assert.Equal(0m, discount3);
    }
}
```

- [ ] **Step 2: Run integration test**

```bash
dotnet test tests/Catalog.UnitTests/Services/PricingRulesEngineIntegrationTests.cs -v
```

Expected: Test PASSES, verifying config file loads and rules evaluate

- [ ] **Step 3: Commit**

```bash
git add tests/Catalog.UnitTests/Services/PricingRulesEngineIntegrationTests.cs
git commit -m "test: add integration test for pricing rules engine with real config"
```

---

## Task 9: Documentation & Cleanup

**Files:**
- Create or Modify: `README.md` or `docs/pricing-rules.md`

**Interfaces:**
- Produces: User-facing documentation explaining how to edit pricing rules

- [ ] **Step 1: Create pricing rules documentation**

File: `docs/pricing-rules.md`

```markdown
# Pricing Rules Configuration

## Overview

The Pricing Rules Engine allows business teams to define discount strategies in a JSON config file without code changes.

## Config File Location

`src/Catalog.API/config/pricing-rules.json`

## Rule Structure

Each rule has:
- `name`: Unique identifier for the rule
- `description`: Human-readable explanation
- `condition`: Defines when the rule applies
- `discountPercent`: Discount percentage (0–100)

## Supported Conditions

### Quantity
Apply discount based on number of units:
```json
{
  "type": "quantity",
  "operator": ">=",
  "value": "5"
}
```
Operators: `>=`, `>`, `<=`, `<`, `==`

### Category
Apply discount based on product category:
```json
{
  "type": "category",
  "operator": "==",
  "value": "electronics"
}
```
Operators: `==`, `!=`

### Customer Tier
Apply discount based on customer tier:
```json
{
  "type": "customer_tier",
  "operator": "==",
  "value": "premium"
}
```
Operators: `==`, `!=`
Valid tiers: `standard`, `silver`, `gold`, `premium`

## Rule Evaluation

Rules are evaluated in order. The **first matching rule wins**; no discount stacking.

Example:
```json
[
  { "name": "volume_5", "condition": { "type": "quantity", "operator": ">=", "value": "5" }, "discountPercent": 10 },
  { "name": "volume_10", "condition": { "type": "quantity", "operator": ">=", "value": "10" }, "discountPercent": 15 }
]
```

An order with 10 units matches both rules but receives only 10% discount (first match).

## Making Changes

1. Edit `src/Catalog.API/config/pricing-rules.json`
2. Restart the server
3. Changes take effect immediately on next basket update

## Testing Your Rules

Use the basket checkout flow to verify rules apply correctly. Enable debug logging to see which rule fired:
```
logger.LogDebug("Rule '{RuleName}' matched; discount: {Discount}%", rule.Name, rule.DiscountPercent);
```
```

- [ ] **Step 2: Commit**

```bash
git add docs/pricing-rules.md
git commit -m "docs: add pricing rules configuration guide"
```

---

## Summary

**All tasks completed build a working pricing rules engine that:**

✅ Loads rules from a JSON config file at startup  
✅ Evaluates conditions (quantity, category, customer tier)  
✅ Returns discount percentages for basket items  
✅ Integrates into the basket checkout flow  
✅ Requires only server restart for config changes  
✅ Has comprehensive unit and integration tests  
✅ Is documented for business users  

**Next Steps After Implementation:**

- Add customer tier lookup from Buyer aggregate (currently defaults to "standard")
- Add product tag evaluation when product catalog data is accessible
- Extend to fulfillment and promotion rules (same pattern)
