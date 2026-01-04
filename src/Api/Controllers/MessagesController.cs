using Application.Commands.PublishMessage;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MessagesController : ControllerBase
{
    private readonly MediatR.IMediator _mediator;

    public MessagesController(MediatR.IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost("publish")]
    public async Task<IActionResult> Publish([FromBody] PublishDto dto)
    {
        var id = await _mediator.Send(new PublishMessageCommand(dto.Text, dto.ForceFail));
        return Accepted(new { id });
    }

    public record PublishDto(string Text, bool ForceFail = false);
}