import { Catch, ExceptionFilter, HttpException } from "@nestjs/common";
import type { ArgumentsHost } from "@nestjs/common";
import type { FastifyReply, FastifyRequest } from "fastify";

@Catch(HttpException)
export class HttpExceptionResponseFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<FastifyReply>();
    const request = host.switchToHttp().getRequest<FastifyRequest>();
    const requestId = String(request.headers["x-request-id"] ?? crypto.randomUUID());
    const status = exception.getStatus();
    const payload = exception.getResponse();
    const message = typeof payload === "string" ? payload : ((payload as { message?: string|string[] }).message ?? exception.message);
    response.header("x-request-id", requestId).status(status).send({ error: { code: codeForStatus(status), message: Array.isArray(message) ? message.join(" ") : message, requestId } });
  }
}
function codeForStatus(status: number) { return ({ 400: "VALIDATION_FAILED", 401: "AUTHENTICATION_REQUIRED", 403: "FORBIDDEN", 404: "RESOURCE_NOT_FOUND", 409: "CONFLICT", 422: "VALIDATION_FAILED" } as Record<number, string>)[status] ?? "REQUEST_FAILED"; }
