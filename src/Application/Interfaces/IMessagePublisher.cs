using Domain.Entities;

namespace Application.Interfaces;

public interface IMessagePublisher
{
    Task PublishAsync(DemoMessage message);
}