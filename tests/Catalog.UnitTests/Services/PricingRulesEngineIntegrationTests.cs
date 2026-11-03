namespace eShop.Catalog.UnitTests.Services;

using Microsoft.Extensions.Configuration;
using eShop.Catalog.API.Services.Pricing;

[TestClass]
public class PricingRulesEngineIntegrationTests
{
    [TestMethod]
    public void LoadConfigFile_ParsesCorrectly_AndEvaluatesRules()
    {
        var configPath = Path.Combine(
            AppContext.BaseDirectory,
            "config", "pricing-rules.json");

        Assert.IsTrue(File.Exists(configPath), $"Config file not found at {configPath}");

        var config = new ConfigurationBuilder()
            .AddJsonFile(configPath)
            .Build();

        var logger = new NullLogger<PricingRulesEngine>();
        var engine = new PricingRulesEngine(config, logger);

        // Test volume discount rule (5 units >= 5, first-match-wins)
        var discount1 = engine.CalculateDiscount("electronics", 5, "standard");
        Assert.AreEqual(10m, discount1, "Expected 10% discount for 5+ units");

        // Test category discount rule (electronics, but volume rule matches first)
        var discount2 = engine.CalculateDiscount("electronics", 1, "standard");
        Assert.AreEqual(5m, discount2, "Expected 5% discount from electronics category rule");

        // Test premium customer discount (matches first in rule order)
        var discount3 = engine.CalculateDiscount("books", 2, "premium");
        Assert.AreEqual(20m, discount3, "Expected 20% discount for premium tier");

        // Test no matching rule
        var discount4 = engine.CalculateDiscount("furniture", 1, "standard");
        Assert.AreEqual(0m, discount4, "Expected 0% discount when no rule matches");
    }
}
