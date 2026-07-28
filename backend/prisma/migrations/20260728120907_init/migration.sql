-- CreateEnum
CREATE TYPE "account_status" AS ENUM ('pending', 'approved', 'rejected', 'suspended');

-- CreateEnum
CREATE TYPE "assignment_status" AS ENUM ('notified', 'accepted', 'declined', 'expired');

-- CreateEnum
CREATE TYPE "dispute_status" AS ENUM ('open', 'under_review', 'resolved', 'rejected');

-- CreateEnum
CREATE TYPE "driver_availability" AS ENUM ('available', 'busy', 'offline');

-- CreateEnum
CREATE TYPE "listing_status" AS ENUM ('active', 'sold', 'expired', 'flagged', 'cancelled');

-- CreateEnum
CREATE TYPE "order_status" AS ENUM ('pending_payment', 'awaiting_driver', 'driver_assigned', 'in_transit', 'delivered_pending_confirmation', 'completed', 'disputed', 'cancelled');

-- CreateEnum
CREATE TYPE "payment_status" AS ENUM ('held', 'released', 'refunded');

-- CreateEnum
CREATE TYPE "transport_mode" AS ENUM ('self_collect', 'driver_assisted');

-- CreateEnum
CREATE TYPE "user_role" AS ENUM ('farmer', 'buyer', 'driver', 'admin');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "phone_number" VARCHAR(20) NOT NULL,
    "full_name" VARCHAR(150) NOT NULL,
    "role" "user_role" NOT NULL,
    "region" VARCHAR(100) NOT NULL,
    "otp_verified" BOOLEAN NOT NULL DEFAULT false,
    "account_status" "account_status" NOT NULL DEFAULT 'pending',
    "approved_by" UUID,
    "approved_at" TIMESTAMPTZ(6),
    "fcm_token" VARCHAR(255),
    "momo_number" VARCHAR(20),
    "momo_network" VARCHAR(20),
    "password_hash" VARCHAR(255),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "disputes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "raised_by" UUID NOT NULL,
    "reason" TEXT NOT NULL,
    "status" "dispute_status" NOT NULL DEFAULT 'open',
    "resolved_by" UUID,
    "resolution_notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(6),

    CONSTRAINT "disputes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_trail" (
    "id" BIGSERIAL NOT NULL,
    "event_type" VARCHAR(100) NOT NULL,
    "entity_type" VARCHAR(50) NOT NULL,
    "entity_id" UUID NOT NULL,
    "actor_id" UUID,
    "event_data" JSONB NOT NULL DEFAULT '{}',
    "event_hash" CHAR(64) NOT NULL,
    "previous_hash" CHAR(64),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_trail_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "crop_types" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(100) NOT NULL,
    "category" VARCHAR(100),

    CONSTRAINT "crop_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_assignments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "driver_id" UUID NOT NULL,
    "sequence_number" INTEGER NOT NULL,
    "status" "assignment_status" NOT NULL DEFAULT 'notified',
    "agreed_cash_price" DECIMAL(10,2),
    "notified_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "responded_at" TIMESTAMPTZ(6),

    CONSTRAINT "driver_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_details" (
    "user_id" UUID NOT NULL,
    "truck_capacity_kg" DECIMAL(10,2) NOT NULL,
    "operating_region" VARCHAR(100) NOT NULL,
    "availability_status" "driver_availability" NOT NULL DEFAULT 'offline',
    "current_lat" DECIMAL(9,6),
    "current_lng" DECIMAL(9,6),
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_details_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "mofa_price_references" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "crop_type_id" UUID NOT NULL,
    "region" VARCHAR(100) NOT NULL,
    "price_per_kg" DECIMAL(10,2) NOT NULL,
    "effective_date" DATE NOT NULL,
    "updated_by" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mofa_price_references_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "order_id" UUID,
    "listing_id" UUID,
    "type" VARCHAR(50) NOT NULL,
    "message" TEXT NOT NULL,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "listing_id" UUID NOT NULL,
    "buyer_id" UUID NOT NULL,
    "transport_mode" "transport_mode" NOT NULL,
    "order_status" "order_status" NOT NULL DEFAULT 'pending_payment',
    "amount" DECIMAL(10,2) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "delivered_at" TIMESTAMPTZ(6),
    "completed_at" TIMESTAMPTZ(6),

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "status" "payment_status" NOT NULL DEFAULT 'held',
    "provider" VARCHAR(50) NOT NULL DEFAULT 'paystack',
    "provider_reference" VARCHAR(150),
    "held_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "released_at" TIMESTAMPTZ(6),
    "refunded_at" TIMESTAMPTZ(6),

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "produce_listings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "farmer_id" UUID NOT NULL,
    "crop_type_id" UUID NOT NULL,
    "quantity_kg" DECIMAL(10,2) NOT NULL,
    "region" VARCHAR(100) NOT NULL,
    "gps_lat" DECIMAL(9,6) NOT NULL,
    "gps_lng" DECIMAL(9,6) NOT NULL,
    "freshness_score" DECIMAL(5,2) NOT NULL,
    "estimated_viable_days" INTEGER NOT NULL,
    "mofa_reference_price" DECIMAL(10,2) NOT NULL,
    "price_ceiling" DECIMAL(10,2) NOT NULL,
    "price_floor" DECIMAL(10,2) NOT NULL,
    "listed_price" DECIMAL(10,2) NOT NULL,
    "below_floor_acknowledged" BOOLEAN NOT NULL DEFAULT false,
    "listing_hash" CHAR(64) NOT NULL,
    "qr_code_data" TEXT,
    "status" "listing_status" NOT NULL DEFAULT 'active',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sold_at" TIMESTAMPTZ(6),

    CONSTRAINT "produce_listings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "qr_scans" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "order_id" UUID NOT NULL,
    "scanned_by" UUID NOT NULL,
    "scanned_hash" CHAR(64) NOT NULL,
    "hash_match" BOOLEAN NOT NULL,
    "scanned_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "qr_scans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outbox_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "aggregate_type" VARCHAR(50) NOT NULL,
    "aggregate_id" VARCHAR(255) NOT NULL,
    "event_type" VARCHAR(100) NOT NULL,
    "payload" JSONB NOT NULL,
    "published_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_device_tokens" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "token" VARCHAR(255) NOT NULL,
    "platform" VARCHAR(50),
    "device_id" VARCHAR(100),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "last_used_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_device_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_webhook_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "provider" VARCHAR(50) NOT NULL DEFAULT 'paystack',
    "event_key" VARCHAR(255) NOT NULL,
    "event_type" VARCHAR(100) NOT NULL,
    "reference" VARCHAR(255),
    "payload" JSONB NOT NULL,
    "processing_state" VARCHAR(50) NOT NULL DEFAULT 'pending',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "processed_at" TIMESTAMPTZ(6),
    "last_error" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payment_webhook_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_number_key" ON "users"("phone_number");

-- CreateIndex
CREATE INDEX "idx_users_region" ON "users"("region");

-- CreateIndex
CREATE INDEX "idx_users_role_status" ON "users"("role", "account_status");

-- CreateIndex
CREATE INDEX "idx_disputes_status" ON "disputes"("status");

-- CreateIndex
CREATE INDEX "idx_audit_created" ON "audit_trail"("created_at");

-- CreateIndex
CREATE INDEX "idx_audit_entity" ON "audit_trail"("entity_type", "entity_id");

-- CreateIndex
CREATE UNIQUE INDEX "crop_types_name_key" ON "crop_types"("name");

-- CreateIndex
CREATE INDEX "idx_driver_assignments_driver" ON "driver_assignments"("driver_id", "status");

-- CreateIndex
CREATE INDEX "idx_driver_assignments_order" ON "driver_assignments"("order_id");

-- CreateIndex
CREATE INDEX "idx_driver_assignments_timeout" ON "driver_assignments"("status", "notified_at");

-- CreateIndex
CREATE UNIQUE INDEX "driver_assignments_order_id_sequence_number_key" ON "driver_assignments"("order_id", "sequence_number");

-- CreateIndex
CREATE INDEX "idx_driver_region_status" ON "driver_details"("operating_region", "availability_status");

-- CreateIndex
CREATE INDEX "idx_mofa_lookup" ON "mofa_price_references"("crop_type_id", "region", "effective_date" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "mofa_price_references_crop_type_id_region_effective_date_key" ON "mofa_price_references"("crop_type_id", "region", "effective_date");

-- CreateIndex
CREATE INDEX "idx_notifications_user_unread" ON "notifications"("user_id", "is_read");

-- CreateIndex
CREATE UNIQUE INDEX "orders_listing_id_key" ON "orders"("listing_id");

-- CreateIndex
CREATE INDEX "idx_orders_buyer" ON "orders"("buyer_id");

-- CreateIndex
CREATE INDEX "idx_orders_status" ON "orders"("order_status");

-- CreateIndex
CREATE UNIQUE INDEX "payments_order_id_key" ON "payments"("order_id");

-- CreateIndex
CREATE UNIQUE INDEX "produce_listings_listing_hash_key" ON "produce_listings"("listing_hash");

-- CreateIndex
CREATE INDEX "idx_listings_farmer" ON "produce_listings"("farmer_id");

-- CreateIndex
CREATE INDEX "idx_listings_marketplace" ON "produce_listings"("status", "region", "crop_type_id", "freshness_score");

-- CreateIndex
CREATE INDEX "idx_listings_status_created" ON "produce_listings"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "idx_listings_status_freshness" ON "produce_listings"("status", "freshness_score" DESC);

-- CreateIndex
CREATE INDEX "idx_listings_status_price_high" ON "produce_listings"("status", "listed_price" DESC);

-- CreateIndex
CREATE INDEX "idx_listings_status_price_low" ON "produce_listings"("status", "listed_price");

-- CreateIndex
CREATE INDEX "idx_listings_status_quantity" ON "produce_listings"("status", "quantity_kg" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "qr_scans_order_id_key" ON "qr_scans"("order_id");

-- CreateIndex
CREATE INDEX "idx_outbox_published_created" ON "outbox_events"("published_at", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "user_device_tokens_token_key" ON "user_device_tokens"("token");

-- CreateIndex
CREATE INDEX "idx_device_tokens_user_active" ON "user_device_tokens"("user_id", "is_active");

-- CreateIndex
CREATE UNIQUE INDEX "payment_webhook_events_event_key_key" ON "payment_webhook_events"("event_key");

-- CreateIndex
CREATE INDEX "idx_webhook_events_state_created" ON "payment_webhook_events"("processing_state", "created_at");

-- CreateIndex
CREATE INDEX "idx_webhook_events_reference" ON "payment_webhook_events"("reference");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "disputes" ADD CONSTRAINT "disputes_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "disputes" ADD CONSTRAINT "disputes_raised_by_fkey" FOREIGN KEY ("raised_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "disputes" ADD CONSTRAINT "disputes_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "audit_trail" ADD CONSTRAINT "audit_trail_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "driver_assignments" ADD CONSTRAINT "driver_assignments_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "driver_assignments" ADD CONSTRAINT "driver_assignments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "driver_details" ADD CONSTRAINT "driver_details_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "mofa_price_references" ADD CONSTRAINT "mofa_price_references_crop_type_id_fkey" FOREIGN KEY ("crop_type_id") REFERENCES "crop_types"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "mofa_price_references" ADD CONSTRAINT "mofa_price_references_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "produce_listings"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_buyer_id_fkey" FOREIGN KEY ("buyer_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES "produce_listings"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "produce_listings" ADD CONSTRAINT "produce_listings_crop_type_id_fkey" FOREIGN KEY ("crop_type_id") REFERENCES "crop_types"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "produce_listings" ADD CONSTRAINT "produce_listings_farmer_id_fkey" FOREIGN KEY ("farmer_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "qr_scans" ADD CONSTRAINT "qr_scans_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "qr_scans" ADD CONSTRAINT "qr_scans_scanned_by_fkey" FOREIGN KEY ("scanned_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_device_tokens" ADD CONSTRAINT "user_device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
