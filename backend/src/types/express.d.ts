// `export {}` makes this file a module, which `declare global` requires — without
// it TypeScript rejects the augmentation ("Augmentations for the global scope can
// only be directly nested in external modules"). An unused
// `import { Request } from 'express'` was doing that job, which read as a stray
// import and was reported as an unused variable.
//
// Note this augmentation is currently unused: authenticate.ts writes the auth
// context via `(req as any).user = decoded`, and all 20 read sites cast the same
// way, so `req.user` is untyped everywhere. Dropping the casts in favour of this
// declaration would restore that type safety, but each site then has to handle
// `user` being optional — worth doing deliberately rather than as a lint fix.
export {};

declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string;
        role: string;
      };
    }
  }
}
