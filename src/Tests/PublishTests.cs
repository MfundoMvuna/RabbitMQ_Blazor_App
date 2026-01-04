using System;
using System.Threading;
using System.Threading.Tasks;
using MassTransit;
using Xunit;
using FluentAssertions;
using Domain.Entities;

namespace DemoApi.Tests;
public class PublishTests
{
    [Fact]
    public async Task PublishMessage_IsConsumed()
    {
        var tcs = new TaskCompletionSource<DemoMessage?>(TaskCreationOptions.RunContinuationsAsynchronously);

        var bus = Bus.Factory.CreateUsingInMemory(cfg =>
        {
            cfg.ReceiveEndpoint("input-queue", e =>
            {
                e.Consumer(() => new TestConsumer(tcs));
            });
        });

        await bus.StartAsync();
        try
        {
            var sendEndpoint = await bus.GetSendEndpoint(new Uri("loopback://localhost/input-queue"));
            var msg = new DemoMessage(Guid.NewGuid(), "hi", "tester", DateTime.UtcNow);
            await sendEndpoint.Send(msg);

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            var completed = await Task.WhenAny(tcs.Task, Task.Delay(Timeout.InfiniteTimeSpan, cts.Token));
            Assert.True(completed == tcs.Task, "Message was not consumed within timeout");

            var consumed = await tcs.Task; // re-await to propagate exceptions
            consumed.Should().NotBeNull();
            consumed!.Id.Should().Be(msg.Id);
        }
        finally
        {
            await bus.StopAsync();
        }
    }

    class TestConsumer : IConsumer<DemoMessage>
    {
        private readonly TaskCompletionSource<DemoMessage?> _tcs;

        public TestConsumer(TaskCompletionSource<DemoMessage?> tcs)
        {
            _tcs = tcs;
        }

        public Task Consume(ConsumeContext<DemoMessage> context)
        {
            _tcs.TrySetResult(context.Message);
            return Task.CompletedTask;
        }
    }
}