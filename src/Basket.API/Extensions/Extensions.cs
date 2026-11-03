using System.Text.Json.Serialization;
using eShop.Basket.API.Repositories;
using eShop.Basket.API.IntegrationEvents.EventHandling;
using eShop.Basket.API.IntegrationEvents.EventHandling.Events;
using eShop.Catalog.API.Services.Pricing;

namespace eShop.Basket.API.Extensions;

public static class Extensions
{
    public static void AddApplicationServices(this IHostApplicationBuilder builder)
    {
        builder.AddDefaultAuthentication();

        builder.AddRedisClient("redis");

        builder.Services.AddSingleton<IBasketRepository, RedisBasketRepository>();

        // Register pricing rules engine
        var pricingConfigPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "Catalog.API", "config", "pricing-rules.json");
        var pricingConfig = new Microsoft.Extensions.Configuration.ConfigurationBuilder()
            .AddJsonFile(pricingConfigPath, optional: true, reloadOnChange: false)
            .Build();

        builder.Services.AddSingleton<IPricingRulesEngine>(sp =>
            new PricingRulesEngine(pricingConfig, sp.GetRequiredService<ILogger<PricingRulesEngine>>()));

        builder.AddRabbitMqEventBus("eventbus")
               .AddSubscription<OrderStartedIntegrationEvent, OrderStartedIntegrationEventHandler>()
               .ConfigureJsonOptions(options => options.TypeInfoResolverChain.Add(IntegrationEventContext.Default));
    }
}

[JsonSerializable(typeof(OrderStartedIntegrationEvent))]
partial class IntegrationEventContext : JsonSerializerContext
{

}
