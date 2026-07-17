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

export const verifyOtpHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await authService.verifyOtp(req.body);
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
