namespace Domain.Entities;

public record DemoMessage(Guid Id, string Text, string CreatedBy, DateTime CreatedAt, bool ForceFail = false);