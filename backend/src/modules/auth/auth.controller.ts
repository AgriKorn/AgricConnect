import { Request, Response, NextFunction } from 'express';
import { sendSuccess } from '../../utils/response';
import { authService } from './auth.service';

export const registerHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await authService.register(req.body);
    sendSuccess(res, result, 201);
  } catch (err) {
    next(err);
  }
};

export const forgotPasswordHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await authService.forgotPassword(req.body);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

export const resetPasswordHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await authService.resetPassword(req.body);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

export const loginHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await authService.login(req.body);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

export const refreshHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await authService.refresh(req.body.refreshToken);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

export const logoutHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await authService.logout(req.body.refreshToken);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

export const getGoogleAuthUrlHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const redirectTo = req.query.redirectTo as string | undefined;
    const result = await authService.getGoogleAuthUrl(redirectTo);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

export const googleAuthHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await authService.googleAuth(req.body);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};
