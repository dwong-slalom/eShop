namespace eShop.Catalog.UnitTests.Services;

using Microsoft.Extensions.Configuration;
using eShop.Catalog.API.Services.Pricing;

[TestClass]
public class PricingRulesEngineTests
{
    [TestMethod]
    public void CalculateDiscount_NoRules_ReturnsZero()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string> { })
            .Build();
        
        var logger = new NullLogger<PricingRulesEngine>();
        var engine = new PricingRulesEngine(config, logger);
        var discount = engine.CalculateDiscount("electronics", 5, "standard");
        
        Assert.AreEqual(0m, discount);
    }

    [TestMethod]
    [DataRow(">=", 5, 5, true)]
    [DataRow(">=", 6, 5, true)]
    [DataRow(">=", 4, 5, false)]
    [DataRow(">", 6, 5, true)]
    [DataRow(">", 5, 5, false)]
    [DataRow("<=", 5, 5, true)]
    [DataRow("<=", 4, 5, true)]
    [DataRow("<=", 6, 5, false)]
    [DataRow("<", 4, 5, true)]
    [DataRow("<", 5, 5, false)]
    [DataRow("==", 5, 5, true)]
    [DataRow("==", 6, 5, false)]
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

        var logger = new NullLogger<PricingRulesEngine>();
        var engine = new PricingRulesEngine(config, logger);
        var discount = engine.CalculateDiscount("electronics", quantity, "standard");

        if (shouldMatch)
            Assert.AreEqual(10m, discount, $"Expected 10% discount for {op} {threshold} with quantity {quantity}");
        else
            Assert.AreEqual(0m, discount, $"Expected 0% discount for {op} {threshold} with quantity {quantity}");
    }

    [TestMethod]
    [DataRow("==", "electronics", "electronics", true)]
    [DataRow("==", "electronics", "books", false)]
    [DataRow("!=", "electronics", "books", true)]
    [DataRow("!=", "electronics", "electronics", false)]
    public void CalculateDiscount_CategoryRule_EvaluatesCorrectly(string op, string category, string value, bool shouldMatch)
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string>
            {
                ["pricing:rules:0:name"] = "category_rule",
                ["pricing:rules:0:condition:type"] = "category",
                ["pricing:rules:0:condition:operator"] = op,
                ["pricing:rules:0:condition:value"] = value,
                ["pricing:rules:0:discountPercent"] = "5"
            })
            .Build();

        var logger = new NullLogger<PricingRulesEngine>();
        var engine = new PricingRulesEngine(config, logger);
        var discount = engine.CalculateDiscount(category, 1, "standard");

        if (shouldMatch)
            Assert.AreEqual(5m, discount);
        else
            Assert.AreEqual(0m, discount);
    }

    [TestMethod]
    [DataRow("==", "premium", "premium", true)]
    [DataRow("==", "premium", "standard", false)]
    [DataRow("!=", "premium", "standard", true)]
    [DataRow("!=", "premium", "premium", false)]
    public void CalculateDiscount_CustomerTierRule_EvaluatesCorrectly(string op, string tier, string value, bool shouldMatch)
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string>
            {
                ["pricing:rules:0:name"] = "tier_rule",
                ["pricing:rules:0:condition:type"] = "customer_tier",
                ["pricing:rules:0:condition:operator"] = op,
                ["pricing:rules:0:condition:value"] = value,
                ["pricing:rules:0:discountPercent"] = "20"
            })
            .Build();

        var logger = new NullLogger<PricingRulesEngine>();
        var engine = new PricingRulesEngine(config, logger);
        var discount = engine.CalculateDiscount("electronics", 1, tier);

        if (shouldMatch)
            Assert.AreEqual(20m, discount);
        else
            Assert.AreEqual(0m, discount);
    }

    [TestMethod]
    public void CalculateDiscount_FirstMatchWins_IgnoresLaterRules()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string>
            {
                ["pricing:rules:0:name"] = "volume_5",
                ["pricing:rules:0:condition:type"] = "quantity",
                ["pricing:rules:0:condition:operator"] = ">=",
                ["pricing:rules:0:condition:value"] = "5",
                ["pricing:rules:0:discountPercent"] = "10",
                
                ["pricing:rules:1:name"] = "volume_10",
                ["pricing:rules:1:condition:type"] = "quantity",
                ["pricing:rules:1:condition:operator"] = ">=",
                ["pricing:rules:1:condition:value"] = "10",
                ["pricing:rules:1:discountPercent"] = "15"
            })
            .Build();

        var logger = new NullLogger<PricingRulesEngine>();
        var engine = new PricingRulesEngine(config, logger);
        
        // 10 units should match first rule (>=5) and return 10%, not second rule's 15%
        var discount = engine.CalculateDiscount("electronics", 10, "standard");
        Assert.AreEqual(10m, discount);
    }
}
