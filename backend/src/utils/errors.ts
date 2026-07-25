export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly isOperational: boolean;

  constructor(message: string, statusCode: number, code: string, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = isOperational;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class BadRequestError extends AppError {
  constructor(message = 'Bad request') {
    super(message, 400, 'BAD_REQUEST');
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED');
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Forbidden') {
    super(message, 403, 'FORBIDDEN');
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(message, 404, 'NOT_FOUND');
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Resource already exists', code = 'CONFLICT') {
    super(message, 409, code);
  }
}

export class OAuthProviderError extends AppError {
  constructor(message = 'OAuth provider authentication failed', statusCode = 400) {
    super(message, statusCode, 'OAUTH_PROVIDER_ERROR');
  }
}

export class InvalidTokenError extends AppError {
  constructor(message = 'Provided token is invalid') {
    super(message, 401, 'INVALID_TOKEN');
  }
}

export class TokenExpiredError extends AppError {
  constructor(message = 'Provided token has expired') {
    super(message, 401, 'TOKEN_EXPIRED');
  }
}

export class AccountRejectedError extends AppError {
  constructor(message = 'This account has been rejected by an administrator') {
    super(message, 403, 'ACCOUNT_REJECTED');
  }
}

export class AccountPendingApprovalError extends AppError {
  constructor(message = 'Your account is pending admin approval') {
    super(message, 403, 'ACCOUNT_PENDING_APPROVAL');
  }
}

export class InternalServerError extends AppError {
  constructor(message = 'Internal server error') {
    super(message, 500, 'INTERNAL_SERVER_ERROR', false);
  }
}
