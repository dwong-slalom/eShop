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
