using Domain.Entities;

namespace Application.Commands.PublishMessage;

public record PublishMessageCommand(string Text, bool ForceFail) : MediatR.IRequest<Guid>;

public class PublishMessageCommandHandler : MediatR.IRequestHandler<PublishMessageCommand, Guid>
{
    private readonly Application.Interfaces.IMessagePublisher _publisher;

    public PublishMessageCommandHandler(Application.Interfaces.IMessagePublisher publisher)
    {
        _publisher = publisher;
    }

    public async Task<Guid> Handle(PublishMessageCommand request, CancellationToken cancellationToken)
    {
        var id = Guid.NewGuid();
        var msg = new DemoMessage(id, request.Text, "api_user", DateTime.UtcNow, request.ForceFail);
        await _publisher.PublishAsync(msg);
        return id;
    }
}