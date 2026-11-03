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
