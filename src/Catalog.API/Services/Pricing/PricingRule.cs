namespace eShop.Catalog.API.Services.Pricing;

public class PricingRule
{
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public PricingCondition Condition { get; set; } = new();
    public decimal DiscountPercent { get; set; }
}
