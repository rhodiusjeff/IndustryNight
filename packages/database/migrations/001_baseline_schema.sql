-- 001_baseline_schema.sql
-- Consolidated baseline schema (replaces 001-007 incremental migrations)
-- Generated from dev RDS as of X1 execution on 2026-03-25
-- Do not edit incrementally -- create 002_*.sql for future changes

--
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 18.2

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;

--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';

--
-- Name: actor_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.actor_type AS ENUM (
    'user',
    'admin',
    'system'
);

--
-- Name: admin_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.admin_role AS ENUM (
    'platformAdmin',
    'moderator',
    'eventOps'
);

--
-- Name: audit_action; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.audit_action AS ENUM (
    'create',
    'update',
    'delete',
    'login',
    'logout',
    'verify',
    'reject',
    'ban',
    'unban',
    'checkin'
);

--
-- Name: audit_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.audit_result AS ENUM (
    'success',
    'failure'
);

--
-- Name: contact_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contact_role AS ENUM (
    'primary',
    'billing',
    'decision_maker',
    'other'
);

--
-- Name: customer_product_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_product_status AS ENUM (
    'active',
    'expired',
    'cancelled',
    'pending'
);

--
-- Name: discount_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.discount_type AS ENUM (
    'percentage',
    'fixedAmount',
    'freeItem',
    'buyOneGetOne',
    'other'
);

--
-- Name: event_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.event_status AS ENUM (
    'draft',
    'published',
    'cancelled',
    'completed'
);

--
-- Name: media_placement; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.media_placement AS ENUM (
    'app_banner',
    'web_banner',
    'social_media',
    'logo',
    'other'
);

--
-- Name: order_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_status AS ENUM (
    'draft',
    'confirmed',
    'paid',
    'fulfilled',
    'cancelled'
);

--
-- Name: post_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.post_type AS ENUM (
    'general',
    'collaboration',
    'job',
    'announcement'
);

--
-- Name: product_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.product_type AS ENUM (
    'sponsorship',
    'vendor_space',
    'data_product'
);

--
-- Name: redemption_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.redemption_method AS ENUM (
    'self_reported',
    'code_entry',
    'qr_scan'
);

--
-- Name: sponsorship_tier; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sponsorship_tier AS ENUM (
    'bronze',
    'silver',
    'gold',
    'platinum'
);

--
-- Name: ticket_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ticket_status AS ENUM (
    'purchased',
    'checkedIn',
    'cancelled',
    'refunded'
);

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'user',
    'platformAdmin'
);

--
-- Name: user_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_source AS ENUM (
    'app',
    'posh',
    'admin'
);

--
-- Name: vendor_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.vendor_category AS ENUM (
    'food',
    'beverage',
    'equipment',
    'service',
    'venue',
    'other'
);

--
-- Name: verification_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.verification_status AS ENUM (
    'unverified',
    'pending',
    'verified',
    'rejected'
);

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

--
--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    name character varying(100) NOT NULL,
    role public.admin_role DEFAULT 'platformAdmin'::public.admin_role NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone
);

--
-- Name: analytics_connections_daily; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_connections_daily (
    date date NOT NULL,
    event_id uuid NOT NULL,
    city character varying(100),
    specialty_a character varying(50) NOT NULL,
    specialty_b character varying(50) NOT NULL,
    connection_count integer DEFAULT 0 NOT NULL
);

--
-- Name: analytics_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_events (
    event_id uuid NOT NULL,
    total_checkins integer DEFAULT 0 NOT NULL,
    unique_attendees integer DEFAULT 0 NOT NULL,
    connections_made integer DEFAULT 0 NOT NULL,
    top_specialties jsonb,
    avg_connections_per_user numeric(5,2),
    cross_specialty_rate numeric(5,4),
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: analytics_influence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_influence (
    user_id uuid NOT NULL,
    connection_count integer DEFAULT 0 NOT NULL,
    events_attended integer DEFAULT 0 NOT NULL,
    network_reach integer DEFAULT 0 NOT NULL,
    specialty_rank integer,
    city_rank integer,
    influence_score numeric(10,4),
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: analytics_users_daily; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_users_daily (
    date date NOT NULL,
    city character varying(100) NOT NULL,
    specialty character varying(50) NOT NULL,
    new_users integer DEFAULT 0 NOT NULL,
    active_users integer DEFAULT 0 NOT NULL,
    verified_users integer DEFAULT 0 NOT NULL,
    checkins integer DEFAULT 0 NOT NULL
);

--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    action public.audit_action NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id uuid,
    actor_id uuid,
    old_values jsonb,
    new_values jsonb,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    admin_actor_id uuid,
    actor_type public.actor_type DEFAULT 'system'::public.actor_type NOT NULL,
    result public.audit_result DEFAULT 'success'::public.audit_result NOT NULL,
    failure_reason character varying(100),
    request_id uuid,
    route character varying(255),
    method character varying(10),
    status_code integer,
    source_ip inet,
    user_agent text,
    environment character varying(20) DEFAULT 'development'::character varying NOT NULL,
    metadata_version integer DEFAULT 1 NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    ingested_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_audit_log_actor_identity CHECK ((((actor_type = 'user'::public.actor_type) AND (actor_id IS NOT NULL) AND (admin_actor_id IS NULL)) OR ((actor_type = 'admin'::public.actor_type) AND (actor_id IS NULL) AND (admin_actor_id IS NOT NULL)) OR ((actor_type = 'system'::public.actor_type) AND (actor_id IS NULL) AND (admin_actor_id IS NULL)))),
    CONSTRAINT ck_audit_log_environment CHECK (((environment)::text = ANY ((ARRAY['development'::character varying, 'production'::character varying, 'test'::character varying])::text[])))
);

--
-- Name: connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.connections (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_a_id uuid NOT NULL,
    user_b_id uuid NOT NULL,
    event_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT different_users CHECK ((user_a_id <> user_b_id))
);

--
-- Name: customer_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_contacts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    customer_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255),
    phone character varying(20),
    role public.contact_role DEFAULT 'other'::public.contact_role NOT NULL,
    title character varying(255),
    is_primary boolean DEFAULT false NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: customer_markets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_markets (
    customer_id uuid NOT NULL,
    market_id uuid NOT NULL
);

--
-- Name: customer_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_media (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    customer_id uuid NOT NULL,
    url text NOT NULL,
    placement public.media_placement DEFAULT 'other'::public.media_placement NOT NULL,
    width integer,
    height integer,
    alt_text character varying(255),
    sort_order smallint DEFAULT 0 NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: customer_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_products (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    customer_id uuid NOT NULL,
    product_id uuid NOT NULL,
    event_id uuid,
    status public.customer_product_status DEFAULT 'active'::public.customer_product_status NOT NULL,
    price_paid_cents integer,
    start_date date,
    end_date date,
    config_overrides jsonb DEFAULT '{}'::jsonb NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    website character varying(500),
    logo_url text,
    contact_email character varying(255),
    contact_phone character varying(20),
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: data_export_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_export_requests (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    request_type character varying(50) NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    download_url text,
    expires_at timestamp with time zone
);

--
-- Name: discount_redemptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discount_redemptions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    discount_id uuid NOT NULL,
    user_id uuid NOT NULL,
    method public.redemption_method DEFAULT 'self_reported'::public.redemption_method NOT NULL,
    redeemed_at timestamp with time zone DEFAULT now() NOT NULL,
    notes text
);

--
-- Name: discounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discounts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    customer_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    type public.discount_type DEFAULT 'percentage'::public.discount_type NOT NULL,
    value numeric(10,2),
    code character varying(50),
    terms text,
    is_active boolean DEFAULT true NOT NULL,
    start_date timestamp with time zone,
    end_date timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: event_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_images (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    event_id uuid NOT NULL,
    url text NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    venue_name character varying(255),
    venue_address text,
    market_id uuid,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone NOT NULL,
    activation_code character varying(20),
    posh_event_id character varying(255),
    status public.event_status DEFAULT 'draft'::public.event_status NOT NULL,
    capacity integer,
    attendee_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    posh_event_url text
);

--
-- Name: llm_usage_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_usage_log (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    feature text NOT NULL,
    model text NOT NULL,
    input_tokens integer,
    output_tokens integer,
    latency_ms integer,
    success boolean NOT NULL,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: markets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.markets (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(100) NOT NULL,
    slug character varying(50) NOT NULL,
    description text,
    timezone character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    event_id uuid,
    unit_price_cents integer,
    quantity integer DEFAULT 1 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    customer_id uuid NOT NULL,
    order_number character varying(20) NOT NULL,
    order_date timestamp with time zone DEFAULT now() NOT NULL,
    status public.order_status DEFAULT 'draft'::public.order_status NOT NULL,
    total_amount_cents integer,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: partner_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.partner_media (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_item_id uuid NOT NULL,
    url text NOT NULL,
    placement public.media_placement DEFAULT 'other'::public.media_placement NOT NULL,
    width integer,
    height integer,
    alt_text character varying(255),
    sort_order smallint DEFAULT 0 NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: platform_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_config (
    key text NOT NULL,
    value jsonb NOT NULL,
    description text,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: posh_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posh_orders (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    posh_event_id character varying(255) NOT NULL,
    order_number character varying(255) NOT NULL,
    event_id uuid,
    account_first_name character varying(100),
    account_last_name character varying(100),
    account_email character varying(255),
    account_phone character varying(20),
    items jsonb NOT NULL,
    subtotal numeric(10,2),
    total numeric(10,2),
    promo_code character varying(50),
    date_purchased timestamp with time zone,
    user_id uuid,
    invite_sent_at timestamp with time zone,
    checked_in_at timestamp with time zone,
    raw_payload jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: post_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_comments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    post_id uuid NOT NULL,
    author_id uuid NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: post_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_likes (
    post_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    author_id uuid NOT NULL,
    content text NOT NULL,
    image_urls text[] DEFAULT '{}'::text[],
    type public.post_type DEFAULT 'general'::public.post_type NOT NULL,
    is_pinned boolean DEFAULT false NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    comment_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    product_type public.product_type NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    base_price_cents integer,
    is_standard boolean DEFAULT true NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: specialties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.specialties (
    id character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    category character varying(50) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);

--
-- Name: tickets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tickets (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    event_id uuid NOT NULL,
    posh_ticket_id character varying(255),
    posh_order_id character varying(255),
    ticket_type character varying(100) NOT NULL,
    price numeric(10,2) NOT NULL,
    status public.ticket_status DEFAULT 'purchased'::public.ticket_status NOT NULL,
    checked_in_at timestamp with time zone,
    purchased_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    wristband_issued_at timestamp with time zone
);

--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    phone character varying(20) NOT NULL,
    email character varying(255),
    name character varying(100),
    bio text,
    profile_photo_url text,
    role public.user_role DEFAULT 'user'::public.user_role NOT NULL,
    source public.user_source DEFAULT 'app'::public.user_source NOT NULL,
    specialties text[] DEFAULT '{}'::text[],
    social_links jsonb,
    verification_status public.verification_status DEFAULT 'unverified'::public.verification_status NOT NULL,
    profile_completed boolean DEFAULT false NOT NULL,
    banned boolean DEFAULT false NOT NULL,
    analytics_consent boolean DEFAULT false NOT NULL,
    marketing_consent boolean DEFAULT false NOT NULL,
    profile_visibility character varying(20) DEFAULT 'connections'::character varying NOT NULL,
    consent_updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    fcm_token text,
    primary_specialty_id character varying(50)
);

--
-- Name: verification_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.verification_codes (
    phone character varying(20) NOT NULL,
    code character varying(6) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--

--
-- Name: admin_users admin_users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_email_key UNIQUE (email);

--
-- Name: admin_users admin_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);

--
-- Name: analytics_connections_daily analytics_connections_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_connections_daily
    ADD CONSTRAINT analytics_connections_daily_pkey PRIMARY KEY (date, event_id, specialty_a, specialty_b);

--
-- Name: analytics_events analytics_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT analytics_events_pkey PRIMARY KEY (event_id);

--
-- Name: analytics_influence analytics_influence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_influence
    ADD CONSTRAINT analytics_influence_pkey PRIMARY KEY (user_id);

--
-- Name: analytics_users_daily analytics_users_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_users_daily
    ADD CONSTRAINT analytics_users_daily_pkey PRIMARY KEY (date, city, specialty);

--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);

--
-- Name: connections connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_pkey PRIMARY KEY (id);

--
-- Name: customer_contacts customer_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_contacts
    ADD CONSTRAINT customer_contacts_pkey PRIMARY KEY (id);

--
-- Name: customer_markets customer_markets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_markets
    ADD CONSTRAINT customer_markets_pkey PRIMARY KEY (customer_id, market_id);

--
-- Name: customer_media customer_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_media
    ADD CONSTRAINT customer_media_pkey PRIMARY KEY (id);

--
-- Name: customer_products customer_products_customer_id_product_id_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_products
    ADD CONSTRAINT customer_products_customer_id_product_id_event_id_key UNIQUE (customer_id, product_id, event_id);

--
-- Name: customer_products customer_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_products
    ADD CONSTRAINT customer_products_pkey PRIMARY KEY (id);

--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);

--
-- Name: data_export_requests data_export_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_export_requests
    ADD CONSTRAINT data_export_requests_pkey PRIMARY KEY (id);

--
-- Name: discount_redemptions discount_redemptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discount_redemptions
    ADD CONSTRAINT discount_redemptions_pkey PRIMARY KEY (id);

--
-- Name: discounts discounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discounts
    ADD CONSTRAINT discounts_pkey PRIMARY KEY (id);

--
-- Name: event_images event_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_images
    ADD CONSTRAINT event_images_pkey PRIMARY KEY (id);

--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);

--
-- Name: llm_usage_log llm_usage_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_usage_log
    ADD CONSTRAINT llm_usage_log_pkey PRIMARY KEY (id);

--
-- Name: markets markets_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT markets_name_key UNIQUE (name);

--
-- Name: markets markets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT markets_pkey PRIMARY KEY (id);

--
-- Name: markets markets_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.markets
    ADD CONSTRAINT markets_slug_key UNIQUE (slug);

--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);

--
-- Name: orders orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_order_number_key UNIQUE (order_number);

--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);

--
-- Name: partner_media partner_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_media
    ADD CONSTRAINT partner_media_pkey PRIMARY KEY (id);

--
-- Name: platform_config platform_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_config
    ADD CONSTRAINT platform_config_pkey PRIMARY KEY (key);

--
-- Name: posh_orders posh_orders_order_number_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posh_orders
    ADD CONSTRAINT posh_orders_order_number_unique UNIQUE (order_number);

--
-- Name: posh_orders posh_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posh_orders
    ADD CONSTRAINT posh_orders_pkey PRIMARY KEY (id);

--
-- Name: post_comments post_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_pkey PRIMARY KEY (id);

--
-- Name: post_likes post_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_pkey PRIMARY KEY (post_id, user_id);

--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);

--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);

--
-- Name: specialties specialties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.specialties
    ADD CONSTRAINT specialties_pkey PRIMARY KEY (id);

--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);

--
-- Name: discount_redemptions unique_user_discount_redemption; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discount_redemptions
    ADD CONSTRAINT unique_user_discount_redemption UNIQUE (discount_id, user_id);

--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);

--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);

--
-- Name: verification_codes verification_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_codes
    ADD CONSTRAINT verification_codes_pkey PRIMARY KEY (phone);

--
-- Name: idx_admin_users_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_active ON public.admin_users USING btree (is_active);

--
-- Name: idx_admin_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_email ON public.admin_users USING btree (email);

--
-- Name: idx_analytics_conn_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analytics_conn_city ON public.analytics_connections_daily USING btree (city);

--
-- Name: idx_analytics_conn_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analytics_conn_date ON public.analytics_connections_daily USING btree (date DESC);

--
-- Name: idx_analytics_influence_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analytics_influence_score ON public.analytics_influence USING btree (influence_score DESC);

--
-- Name: idx_analytics_users_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analytics_users_date ON public.analytics_users_daily USING btree (date DESC);

--
-- Name: idx_audit_log_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_action ON public.audit_log USING btree (action);

--
-- Name: idx_audit_log_action_result_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_action_result_time ON public.audit_log USING btree (action, result, occurred_at DESC);

--
-- Name: idx_audit_log_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_actor ON public.audit_log USING btree (actor_id);

--
-- Name: idx_audit_log_admin_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_admin_actor ON public.audit_log USING btree (admin_actor_id);

--
-- Name: idx_audit_log_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_created_at ON public.audit_log USING btree (created_at DESC);

--
-- Name: idx_audit_log_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_entity ON public.audit_log USING btree (entity_type, entity_id);

--
-- Name: idx_audit_log_failure_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_failure_reason ON public.audit_log USING btree (failure_reason);

--
-- Name: idx_audit_log_metadata; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_metadata ON public.audit_log USING gin (metadata);

--
-- Name: idx_audit_log_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_occurred_at ON public.audit_log USING btree (occurred_at DESC);

--
-- Name: idx_audit_log_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_request_id ON public.audit_log USING btree (request_id);

--
-- Name: idx_audit_log_result; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_result ON public.audit_log USING btree (result);

--
-- Name: idx_connections_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_connections_event ON public.connections USING btree (event_id);

--
-- Name: idx_connections_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_connections_unique ON public.connections USING btree (LEAST(user_a_id, user_b_id), GREATEST(user_a_id, user_b_id));

--
-- Name: idx_connections_user_a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_connections_user_a ON public.connections USING btree (user_a_id);

--
-- Name: idx_connections_user_b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_connections_user_b ON public.connections USING btree (user_b_id);

--
-- Name: idx_customer_contacts_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_contacts_customer ON public.customer_contacts USING btree (customer_id);

--
-- Name: idx_customer_media_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_media_customer ON public.customer_media USING btree (customer_id);

--
-- Name: idx_customer_products_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_products_customer ON public.customer_products USING btree (customer_id);

--
-- Name: idx_customer_products_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_products_event ON public.customer_products USING btree (event_id);

--
-- Name: idx_customer_products_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_products_product ON public.customer_products USING btree (product_id);

--
-- Name: idx_customer_products_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_products_status ON public.customer_products USING btree (status);

--
-- Name: idx_customers_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_active ON public.customers USING btree (is_active);

--
-- Name: idx_customers_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_name ON public.customers USING btree (name);

--
-- Name: idx_data_export_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_data_export_status ON public.data_export_requests USING btree (status);

--
-- Name: idx_data_export_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_data_export_user ON public.data_export_requests USING btree (user_id);

--
-- Name: idx_discount_redemptions_discount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_discount_redemptions_discount ON public.discount_redemptions USING btree (discount_id);

--
-- Name: idx_discount_redemptions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_discount_redemptions_user ON public.discount_redemptions USING btree (user_id);

--
-- Name: idx_discounts_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_discounts_active ON public.discounts USING btree (is_active);

--
-- Name: idx_discounts_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_discounts_customer ON public.discounts USING btree (customer_id);

--
-- Name: idx_event_images_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_event_images_event_id ON public.event_images USING btree (event_id);

--
-- Name: idx_events_market; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_market ON public.events USING btree (market_id);

--
-- Name: idx_events_posh_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_posh_id ON public.events USING btree (posh_event_id);

--
-- Name: idx_events_start_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_start_time ON public.events USING btree (start_time);

--
-- Name: idx_events_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_status ON public.events USING btree (status);

--
-- Name: idx_markets_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_markets_active ON public.markets USING btree (is_active, sort_order);

--
-- Name: idx_markets_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_markets_slug ON public.markets USING btree (slug);

--
-- Name: idx_order_items_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_event ON public.order_items USING btree (event_id);

--
-- Name: idx_order_items_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_order ON public.order_items USING btree (order_id);

--
-- Name: idx_order_items_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_product ON public.order_items USING btree (product_id);

--
-- Name: idx_orders_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_customer ON public.orders USING btree (customer_id);

--
-- Name: idx_orders_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_status ON public.orders USING btree (status);

--
-- Name: idx_partner_media_order_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_partner_media_order_item ON public.partner_media USING btree (order_item_id);

--
-- Name: idx_posh_orders_account_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posh_orders_account_email ON public.posh_orders USING btree (account_email);

--
-- Name: idx_posh_orders_account_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posh_orders_account_phone ON public.posh_orders USING btree (account_phone);

--
-- Name: idx_posh_orders_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posh_orders_event_id ON public.posh_orders USING btree (event_id);

--
-- Name: idx_posh_orders_posh_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posh_orders_posh_event_id ON public.posh_orders USING btree (posh_event_id);

--
-- Name: idx_posh_orders_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posh_orders_user_id ON public.posh_orders USING btree (user_id);

--
-- Name: idx_post_comments_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_post_comments_post ON public.post_comments USING btree (post_id);

--
-- Name: idx_posts_author; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_author ON public.posts USING btree (author_id);

--
-- Name: idx_posts_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_created_at ON public.posts USING btree (created_at DESC);

--
-- Name: idx_posts_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_type ON public.posts USING btree (type);

--
-- Name: idx_products_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_active ON public.products USING btree (is_active);

--
-- Name: idx_products_standard; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_standard ON public.products USING btree (is_standard);

--
-- Name: idx_products_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_type ON public.products USING btree (product_type);

--
-- Name: idx_specialties_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_specialties_active ON public.specialties USING btree (is_active, sort_order);

--
-- Name: idx_specialties_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_specialties_category ON public.specialties USING btree (category);

--
-- Name: idx_tickets_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_event_id ON public.tickets USING btree (event_id);

--
-- Name: idx_tickets_posh_ticket_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_posh_ticket_id ON public.tickets USING btree (posh_ticket_id);

--
-- Name: idx_tickets_posh_ticket_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_tickets_posh_ticket_unique ON public.tickets USING btree (posh_ticket_id) WHERE (posh_ticket_id IS NOT NULL);

--
-- Name: idx_tickets_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_user_id ON public.tickets USING btree (user_id);

--
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);

--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_role ON public.users USING btree (role);

--
-- Name: idx_users_specialties; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_specialties ON public.users USING gin (specialties);

--
-- Name: idx_users_verification_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_verification_status ON public.users USING btree (verification_status);

--
-- Name: prevent_audit_log_mutation(); Type: FUNCTION; Schema: public; Owner: -
-- (Moved after tables: %TYPE requires audit_log to exist at creation time)
--

CREATE FUNCTION public.prevent_audit_log_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_actor_id   audit_log.actor_id%TYPE;
  v_actor_type audit_log.actor_type%TYPE;
BEGIN
  -- Permit FK cascade: ON DELETE SET NULL on audit_log.actor_id (user deleted).
  -- The row must change ONLY actor_id (NULL) and actor_type ('system').
  -- Every other column must be identical to confirm this is a pure FK cascade.
  IF TG_OP = 'UPDATE'
     AND OLD.actor_id IS NOT NULL
     AND NEW.actor_id IS NULL
  THEN
    -- Save intended final values.
    v_actor_id   := NEW.actor_id;   -- will be NULL
    v_actor_type := 'system';

    -- Temporarily restore actor identity to OLD values for full-row comparison.
    NEW.actor_id   := OLD.actor_id;
    NEW.actor_type := OLD.actor_type;

    -- If any other column changed, this is not a pure FK cascade — reject it.
    IF NEW IS DISTINCT FROM OLD THEN
      RAISE EXCEPTION 'audit_log is immutable';
    END IF;

    -- Apply the intended tombstoned actor identity.
    NEW.actor_id   := v_actor_id;
    NEW.actor_type := v_actor_type;
    RETURN NEW;
  END IF;

  -- Permit FK cascade: ON DELETE SET NULL on audit_log.admin_actor_id (admin deleted).
  -- The row must change ONLY admin_actor_id (NULL) and actor_type ('system').
  -- Every other column must be identical to confirm this is a pure FK cascade.
  IF TG_OP = 'UPDATE'
     AND OLD.admin_actor_id IS NOT NULL
     AND NEW.admin_actor_id IS NULL
  THEN
    -- Save intended final values.
    v_actor_id   := NEW.admin_actor_id; -- will be NULL (reuse var for clarity)
    v_actor_type := 'system';

    -- Temporarily restore admin_actor_id and actor_type to OLD values for full-row comparison.
    NEW.admin_actor_id := OLD.admin_actor_id;
    NEW.actor_type     := OLD.actor_type;

    -- If any other column changed, this is not a pure FK cascade — reject it.
    IF NEW IS DISTINCT FROM OLD THEN
      RAISE EXCEPTION 'audit_log is immutable';
    END IF;

    -- Apply the intended tombstoned actor identity.
    NEW.admin_actor_id := NULL;
    NEW.actor_type     := v_actor_type;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'audit_log is immutable';
END;
$$;

--
-- Name: audit_log trg_prevent_audit_log_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_audit_log_delete BEFORE DELETE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_log_mutation();

--
-- Name: audit_log trg_prevent_audit_log_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_audit_log_update BEFORE UPDATE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_log_mutation();

--
-- Name: admin_users update_admin_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_admin_users_updated_at BEFORE UPDATE ON public.admin_users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: customer_contacts update_customer_contacts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_customer_contacts_updated_at BEFORE UPDATE ON public.customer_contacts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: customer_products update_customer_products_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_customer_products_updated_at BEFORE UPDATE ON public.customer_products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: customers update_customers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: discounts update_discounts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_discounts_updated_at BEFORE UPDATE ON public.discounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: events update_events_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: markets update_markets_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_markets_updated_at BEFORE UPDATE ON public.markets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: order_items update_order_items_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_order_items_updated_at BEFORE UPDATE ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: orders update_orders_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: posts update_posts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: products update_products_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

--
-- Name: analytics_connections_daily analytics_connections_daily_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_connections_daily
    ADD CONSTRAINT analytics_connections_daily_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE SET NULL;

--
-- Name: analytics_events analytics_events_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT analytics_events_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;

--
-- Name: analytics_influence analytics_influence_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_influence
    ADD CONSTRAINT analytics_influence_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: audit_log audit_log_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE SET NULL;

--
-- Name: audit_log audit_log_admin_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_admin_actor_id_fkey FOREIGN KEY (admin_actor_id) REFERENCES public.admin_users(id) ON DELETE SET NULL;

--
-- Name: connections connections_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE SET NULL;

--
-- Name: connections connections_user_a_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_user_a_id_fkey FOREIGN KEY (user_a_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: connections connections_user_b_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_user_b_id_fkey FOREIGN KEY (user_b_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: customer_contacts customer_contacts_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_contacts
    ADD CONSTRAINT customer_contacts_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;

--
-- Name: customer_markets customer_markets_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_markets
    ADD CONSTRAINT customer_markets_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;

--
-- Name: customer_markets customer_markets_market_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_markets
    ADD CONSTRAINT customer_markets_market_id_fkey FOREIGN KEY (market_id) REFERENCES public.markets(id) ON DELETE CASCADE;

--
-- Name: customer_media customer_media_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_media
    ADD CONSTRAINT customer_media_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;

--
-- Name: customer_products customer_products_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_products
    ADD CONSTRAINT customer_products_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;

--
-- Name: customer_products customer_products_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_products
    ADD CONSTRAINT customer_products_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE SET NULL;

--
-- Name: customer_products customer_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_products
    ADD CONSTRAINT customer_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;

--
-- Name: data_export_requests data_export_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_export_requests
    ADD CONSTRAINT data_export_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: discount_redemptions discount_redemptions_discount_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discount_redemptions
    ADD CONSTRAINT discount_redemptions_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discounts(id) ON DELETE CASCADE;

--
-- Name: discount_redemptions discount_redemptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discount_redemptions
    ADD CONSTRAINT discount_redemptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: discounts discounts_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discounts
    ADD CONSTRAINT discounts_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;

--
-- Name: event_images event_images_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_images
    ADD CONSTRAINT event_images_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;

--
-- Name: events events_market_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_market_id_fkey FOREIGN KEY (market_id) REFERENCES public.markets(id) ON DELETE RESTRICT;

--
-- Name: order_items order_items_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE SET NULL;

--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;

--
-- Name: orders orders_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;

--
-- Name: partner_media partner_media_order_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_media
    ADD CONSTRAINT partner_media_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON DELETE CASCADE;

--
-- Name: platform_config platform_config_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_config
    ADD CONSTRAINT platform_config_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.admin_users(id) ON DELETE SET NULL;

--
-- Name: posh_orders posh_orders_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posh_orders
    ADD CONSTRAINT posh_orders_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE SET NULL;

--
-- Name: posh_orders posh_orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posh_orders
    ADD CONSTRAINT posh_orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;

--
-- Name: post_comments post_comments_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: post_comments post_comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;

--
-- Name: post_likes post_likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;

--
-- Name: post_likes post_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: posts posts_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: tickets tickets_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;

--
-- Name: tickets tickets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

--
-- Name: users users_primary_specialty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_primary_specialty_id_fkey FOREIGN KEY (primary_specialty_id) REFERENCES public.specialties(id) ON DELETE SET NULL;

--
--
