using Domain.Entities;
using MassTransit;
using Microsoft.Extensions.Logging;

namespace Api.Consumers;

public class DemoMessageConsumer : IConsumer<DemoMessage>
{
    private readonly ILogger<DemoMessageConsumer> _logger;

    public DemoMessageConsumer(ILogger<DemoMessageConsumer> logger)
    {
        _logger = logger;
    }

    public async Task Consume(ConsumeContext<DemoMessage> context)
    {
        _logger.LogInformation("Consumed DemoMessage: {Text} CreatedBy={CreatedBy}", context.Message.Text, context.Message.CreatedBy);

        if (context.Message.ForceFail)
        {
            _logger.LogWarning("DemoMessage requested force-fail: {Id}", context.Message.Id);
            throw new InvalidOperationException("Simulated failure");
        }

        // Simulate processing
        await Task.Delay(100);
        _logger.LogInformation("Processed DemoMessage {Id}", context.Message.Id);
    }
}