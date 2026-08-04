import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { validate } from '../../middleware/validate';
import { createAddressSchema, updateAddressSchema } from './address.schema';
import {
  createAddressHandler,
  deleteAddressHandler,
  listAddressesHandler,
  updateAddressHandler,
} from './address.controller';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /users/addresses:
 *   get:
 *     summary: List the signed-in user's saved delivery addresses
 *     tags: [Addresses]
 *     responses:
 *       200: { description: Addresses returned }
 *   post:
 *     summary: Add a new delivery address
 *     tags: [Addresses]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [label, addressLine]
 *             properties:
 *               label: { type: string, example: Home }
 *               addressLine: { type: string, example: "House No. 24, Spintex Road, Accra" }
 *               region: { type: string, example: "Greater Accra" }
 *               isDefault: { type: boolean }
 *     responses:
 *       201: { description: Address created }
 */
router.get('/', listAddressesHandler);
router.post('/', validate(createAddressSchema), createAddressHandler);

/**
 * @swagger
 * /users/addresses/{id}:
 *   patch:
 *     summary: Update a delivery address
 *     tags: [Addresses]
 *     responses:
 *       200: { description: Address updated }
 *       403: { description: Not your address }
 *       404: { description: Address not found }
 *   delete:
 *     summary: Delete a delivery address
 *     tags: [Addresses]
 *     responses:
 *       200: { description: Address deleted }
 *       403: { description: Not your address }
 *       404: { description: Address not found }
 */
router.patch('/:id', validate(updateAddressSchema), updateAddressHandler);
router.delete('/:id', deleteAddressHandler);

export default router;
