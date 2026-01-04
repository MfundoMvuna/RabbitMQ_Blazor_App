using System.Threading.Tasks;
using MassTransit;
using MassTransit.Testing;
using Xunit;
using DemoApi.Messaging;
using FluentAssertions;
using Domain.Entities;

namespace DemoApi.Tests;
public class PublishTests
{
    [Fact]
    public async Task PublishMessage_IsConsumed()
    {
        await using var harness = new InMemoryTestHarness();
        var consumer = harness.Consumer(() => new TestConsumer());

        await harness.Start();
        try
        {
            await harness.InputQueueSendEndpoint.Send(new DemoMessage(Guid.NewGuid(), "hi", "tester", DateTime.UtcNow));
            Assert.True(await harness.Consumed.Any<DemoMessage>());
            Assert.True(await consumer.Consumed.Any<DemoMessage>());
        }
        finally
        {
            await harness.Stop();
        }
    }

    class TestConsumer : IConsumer<DemoMessage>
    {
        public Task Consume(ConsumeContext<DemoMessage> context)
        {
            return Task.CompletedTask;
        }
    }
}