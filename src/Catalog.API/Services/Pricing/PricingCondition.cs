namespace eShop.Catalog.API.Services.Pricing;

public class PricingCondition
{
    public string Type { get; set; } = string.Empty;
    public string Operator { get; set; } = string.Empty;
    public string Value { get; set; } = string.Empty;
}
