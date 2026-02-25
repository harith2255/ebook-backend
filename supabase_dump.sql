--
-- PostgreSQL database dump
--

\restrict AgtDUb0ibQ7nghHEBXhGS94BX4wsTKNqcwnNAOksvwuLD1jlGSOpOHaNvzIIpiA

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: pyq_paper_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pyq_paper_type AS ENUM (
    'question',
    'answer'
);


--
-- Name: add_revenue_entry(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_revenue_entry() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO revenue (amount)
  VALUES (NEW.amount);
  RETURN NEW;
END;
$$;


--
-- Name: delete_auth_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_auth_user(uid uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  DELETE FROM auth.sessions WHERE user_id = uid;
  DELETE FROM auth.refresh_tokens WHERE user_id = uid::text;
  DELETE FROM auth.identities WHERE user_id = uid;
  DELETE FROM auth.mfa_factors WHERE user_id = uid;
  DELETE FROM auth.flow_state WHERE user_id = uid;

  BEGIN
    DELETE FROM auth.otp WHERE user_id = uid::text;
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;

END;
$$;


--
-- Name: get_monthly_books_sold(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_monthly_books_sold() RETURNS TABLE(month text, total integer)
    LANGUAGE sql
    AS $$
SELECT TO_CHAR(created_at, 'Mon') AS month,
       COUNT(*) AS total
FROM book_sales
GROUP BY 1
ORDER BY MIN(created_at);
$$;


--
-- Name: get_monthly_revenue(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_monthly_revenue() RETURNS TABLE(month text, total numeric)
    LANGUAGE sql
    AS $$
SELECT TO_CHAR(created_at, 'Mon') AS month,
       SUM(amount) AS total
FROM subscriptions
GROUP BY 1
ORDER BY MIN(created_at);
$$;


--
-- Name: get_monthly_user_growth(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_monthly_user_growth() RETURNS TABLE(month text, total integer)
    LANGUAGE sql
    AS $$
SELECT TO_CHAR(created_at, 'Mon') AS month,
       COUNT(*) AS total
FROM auth.users
GROUP BY 1
ORDER BY MIN(created_at);
$$;


--
-- Name: get_user_activity_dates(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_activity_dates(uid uuid) RETURNS TABLE(day date)
    LANGUAGE sql
    AS $$
  select distinct date(created_at) as day from study_sessions where user_id = uid
  union
  select distinct date(completed_at) from mock_attempts where user_id = uid
  union
  select distinct date(added_at) from user_library where user_id = uid
  order by day desc;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    first_name,
    last_name,
    full_name,
    plan,
    status,
    role
  )
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'first_name',
    NEW.raw_user_meta_data->>'last_name',
    NEW.raw_user_meta_data->>'full_name',
    'free',
    'active',
    'User'
  );
  RETURN NEW;
END;
$$;


--
-- Name: increment(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment(x integer) RETURNS integer
    LANGUAGE sql
    AS $$
  select x + 1;
$$;


--
-- Name: increment_current_affairs_views(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_current_affairs_views(row_id uuid) RETURNS void
    LANGUAGE sql
    AS $$
  update current_affairs
  set views = views + 1
  where id = row_id;
$$;


--
-- Name: increment_current_affairs_views_once(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_current_affairs_views_once(p_article_id uuid, p_user_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Try inserting view record
  INSERT INTO current_affairs_views (user_id, article_id)
  VALUES (p_user_id, p_article_id)
  ON CONFLICT DO NOTHING;

  -- Increment only if insert happened
  IF FOUND THEN
    UPDATE current_affairs
    SET views = COALESCE(views, 0) + 1
    WHERE id = p_article_id;
  END IF;
END;
$$;


--
-- Name: increment_participants(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_participants(test_id_input integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  update mock_tests
  set participants = participants + 1
  where id = test_id_input;
end;
$$;


--
-- Name: increment_participants(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_participants(test_id_input bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  update mock_tests
  set participants = coalesce(participants, 0) + 1
  where id = test_id_input;
end;
$$;


--
-- Name: increment_sales(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_sales(book_id bigint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  update ebooks set sales = sales + 1 where id = book_id;
end;
$$;


--
-- Name: recalc_all(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recalc_all() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  perform update_leaderboard();
  perform update_ranks();
end;
$$;


--
-- Name: recreate_auth_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recreate_auth_user(user_id_input uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  insert into auth.users (id, email)
  values (user_id_input, user_id_input || '@deleted.com')
  on conflict (id) do nothing;
end; $$;


--
-- Name: update_leaderboard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_leaderboard() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin

  -- upsert average score + test count
  insert into mock_leaderboard (user_id, average_score, tests_taken)
  select user_id,
         round(avg(score)) as avg_score,
         count(*) as tests_taken
  from mock_attempts
  where status = 'completed'
  group by user_id
  on conflict (user_id)
  do update set
      average_score = excluded.average_score,
      tests_taken = excluded.tests_taken,
      updated_at = now();

end;
$$;


--
-- Name: update_ranks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_ranks() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin

  -- update best_rank in leaderboard
  with ranked as (
    select user_id,
           average_score,
           row_number() over (order by average_score desc) as rnk
    from mock_leaderboard
  )
  update mock_leaderboard l
  set best_rank = r.rnk
  from ranked r
  where l.user_id = r.user_id;

  -- propagate rank back into attempts table
  update mock_attempts a
  set rank = l.best_rank
  from mock_leaderboard l
  where a.user_id = l.user_id
    and a.status = 'completed';

end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activity_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_log (
    id bigint NOT NULL,
    user_name text,
    action text,
    type text,
    created_at timestamp without time zone DEFAULT now(),
    user_id uuid
);


--
-- Name: activity_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.activity_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.activity_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ai_activity_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_activity_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action text NOT NULL,
    status text NOT NULL,
    details text,
    created_at timestamp with time zone DEFAULT now(),
    admin_id uuid
);


--
-- Name: ai_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auto_tagging boolean DEFAULT true,
    summary_generation boolean DEFAULT true,
    plagiarism_detection boolean DEFAULT false,
    smart_recommendations boolean DEFAULT true,
    adaptive_learning boolean DEFAULT true,
    smart_search boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: backups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.backups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status text DEFAULT 'completed'::text,
    file_url text,
    triggered_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: book_sales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.book_sales (
    user_id uuid NOT NULL,
    purchased_at timestamp with time zone DEFAULT now(),
    book_id uuid NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: book_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.book_views (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    book_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: collection_books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collection_books (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    collection_id uuid,
    book_id uuid,
    progress integer DEFAULT 0
);


--
-- Name: collections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collections (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: current_affairs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.current_affairs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    content text NOT NULL,
    tags text,
    importance text DEFAULT 'medium'::text,
    status text DEFAULT 'published'::text,
    article_date date NOT NULL,
    article_time time without time zone NOT NULL,
    image_url text,
    image_path text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    views integer DEFAULT 0,
    CONSTRAINT current_affairs_importance_check CHECK ((importance = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text]))),
    CONSTRAINT current_affairs_status_check CHECK ((status = ANY (ARRAY['published'::text, 'draft'::text, 'archived'::text])))
);


--
-- Name: current_affairs_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.current_affairs_views (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    article_id uuid NOT NULL,
    viewed_at timestamp with time zone DEFAULT now()
);


--
-- Name: downloaded_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.downloaded_notes (
    id bigint NOT NULL,
    user_id uuid,
    note_id bigint,
    downloaded_at timestamp without time zone DEFAULT now()
);


--
-- Name: downloaded_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.downloaded_notes ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.downloaded_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: drm_access_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drm_access_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_name text NOT NULL,
    book_title text NOT NULL,
    action text NOT NULL,
    device_info text,
    ip_address text,
    created_at timestamp with time zone DEFAULT now(),
    book_id uuid,
    user_id uuid
);


--
-- Name: drm_access_logs_view; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.drm_access_logs_view AS
 SELECT id,
    user_id,
    user_name,
    book_id,
    book_title,
    action,
    device_info AS device,
    ip_address,
    created_at
   FROM public.drm_access_logs al
  WITH NO DATA;


--
-- Name: drm_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drm_devices (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    device_id text NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: drm_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.drm_devices ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.drm_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: drm_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drm_settings (
    id bigint DEFAULT 1 NOT NULL,
    copy_protection boolean DEFAULT true NOT NULL,
    watermarking boolean DEFAULT true NOT NULL,
    device_limit integer DEFAULT 3 NOT NULL,
    screenshot_prevention boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: ebook_ratings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ebook_ratings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    ebook_id uuid NOT NULL,
    rating integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT ebook_ratings_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: ebooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ebooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    author text,
    description text,
    pages integer DEFAULT 0,
    price numeric,
    sales integer DEFAULT 0,
    status text DEFAULT 'Published'::text,
    file_url text,
    created_at timestamp with time zone DEFAULT now(),
    tags text[],
    summary text,
    embedding public.vector(1536),
    cover_url text,
    user_id uuid,
    category_id uuid,
    rating numeric(3,2) DEFAULT 0,
    reviews integer DEFAULT 0
);


--
-- Name: exams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exams (
    id integer NOT NULL,
    folder_id integer,
    title text NOT NULL,
    description text,
    file_path text,
    file_name text,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    subject_id integer
);


--
-- Name: exams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.exams_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: exams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.exams_id_seq OWNED BY public.exams.id;


--
-- Name: folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folders (
    id integer NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: folders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.folders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: folders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.folders_id_seq OWNED BY public.folders.id;


--
-- Name: highlights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.highlights (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    page integer NOT NULL,
    text text,
    color text,
    created_at timestamp without time zone DEFAULT now(),
    x double precision,
    y double precision,
    width double precision,
    height double precision,
    book_id uuid
);


--
-- Name: integrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    status text DEFAULT 'disconnected'::text,
    config jsonb DEFAULT '{}'::jsonb,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: interview_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interview_materials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    description text,
    file_url text NOT NULL,
    file_type text DEFAULT 'pdf'::text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: job_requirements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_requirements (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    requirement text NOT NULL
);


--
-- Name: job_requirements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.job_requirements ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.job_requirements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jobs (
    id bigint NOT NULL,
    title text NOT NULL,
    company text NOT NULL,
    location text NOT NULL,
    type text NOT NULL,
    level text NOT NULL,
    salary text,
    posted date DEFAULT now(),
    description text,
    requirements text[],
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jobs_id_seq OWNED BY public.jobs.id;


--
-- Name: mock_answers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mock_answers (
    attempt_id bigint NOT NULL,
    question_id bigint NOT NULL,
    answer text
);


--
-- Name: mock_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mock_attempts (
    id bigint NOT NULL,
    user_id uuid,
    test_id bigint,
    started_at timestamp with time zone DEFAULT now(),
    completed_at timestamp with time zone,
    status text DEFAULT 'in_progress'::text,
    score double precision DEFAULT 0,
    time_spent numeric DEFAULT 0,
    rank integer,
    completed_questions integer DEFAULT 0,
    expires_at timestamp with time zone,
    percentile integer,
    CONSTRAINT mock_attempts_status_check CHECK ((status = ANY (ARRAY['in_progress'::text, 'completed'::text, 'time_expired'::text]))),
    CONSTRAINT percentile_range CHECK (((percentile >= 0) AND (percentile <= 100)))
);


--
-- Name: mock_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mock_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mock_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mock_attempts_id_seq OWNED BY public.mock_attempts.id;


--
-- Name: mock_leaderboard; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mock_leaderboard (
    user_id uuid NOT NULL,
    average_score integer DEFAULT 0,
    tests_taken integer DEFAULT 0,
    best_rank integer,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: mock_test_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mock_test_questions (
    id bigint NOT NULL,
    test_id integer,
    question text NOT NULL,
    option_a text NOT NULL,
    option_b text NOT NULL,
    option_c text NOT NULL,
    option_d text NOT NULL,
    correct_option text NOT NULL,
    explanation text,
    option_e text
);


--
-- Name: mock_test_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mock_test_questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mock_test_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mock_test_questions_id_seq OWNED BY public.mock_test_questions.id;


--
-- Name: mock_tests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mock_tests (
    id bigint NOT NULL,
    title text,
    scheduled_date timestamp with time zone,
    total_questions integer,
    duration_minutes integer DEFAULT 60 NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    subject text DEFAULT 'General'::text,
    difficulty text DEFAULT 'Medium'::text,
    participants integer DEFAULT 0,
    file_url text,
    mcqs jsonb,
    user_id uuid,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    description text,
    status text DEFAULT 'scheduled'::text
);


--
-- Name: mock_tests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mock_tests ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.mock_tests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id bigint NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    author text,
    pages integer DEFAULT 0,
    downloads integer DEFAULT 0,
    rating double precision DEFAULT 0,
    price numeric(6,2) DEFAULT 0.00,
    featured boolean DEFAULT false,
    file_url text,
    preview_content text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    description text,
    tags text[],
    summary text,
    embedding public.vector(1536),
    cover_url text,
    user_id uuid,
    new_id uuid DEFAULT gen_random_uuid(),
    cached_preview text,
    preview_generated boolean DEFAULT false,
    category_id uuid
);


--
-- Name: notes_highlights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes_highlights (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    note_id bigint,
    page integer NOT NULL,
    x_pct numeric,
    y_pct numeric,
    w_pct numeric,
    h_pct numeric,
    color text DEFAULT 'rgba(255,255,0,0.35)'::text,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notes_id_seq OWNED BY public.notes.id;


--
-- Name: notes_purchase; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes_purchase (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    note_id bigint NOT NULL,
    purchased_at timestamp with time zone DEFAULT now()
);


--
-- Name: notes_read_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes_read_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    note_id bigint,
    last_page integer DEFAULT 1,
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: notification_drafts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_drafts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    subject text,
    message text,
    recipient_type text,
    notification_type text,
    custom_list text[],
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: notification_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    subject text NOT NULL,
    message text NOT NULL,
    recipient_type text NOT NULL,
    notification_type text NOT NULL,
    delivered_count integer DEFAULT 0,
    custom_list text[],
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_methods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    provider text,
    display_name text,
    last4 text,
    expiry text,
    is_default boolean DEFAULT false,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: payments_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    plan_id bigint,
    amount numeric NOT NULL,
    currency text DEFAULT 'INR'::text,
    method text,
    status text DEFAULT 'completed'::text,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    external_ref text,
    payment_id text,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text,
    created_at timestamp with time zone DEFAULT now(),
    plan text,
    status text,
    email text,
    role text DEFAULT 'User'::text,
    first_name text,
    last_name text,
    phone text,
    dob date,
    institution text,
    field_of_study text,
    academic_level text,
    bio text,
    avatar_url text,
    email_notifications jsonb DEFAULT '{}'::jsonb,
    push_notifications jsonb DEFAULT '{}'::jsonb,
    account_status text DEFAULT 'active'::text NOT NULL,
    total_spent numeric DEFAULT 0,
    password_hash text,
    must_reset_password boolean DEFAULT false,
    reset_token text,
    reset_token_expires timestamp with time zone,
    CONSTRAINT account_status_check CHECK ((account_status = ANY (ARRAY['active'::text, 'suspended'::text, 'banned'::text])))
);


--
-- Name: purchases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchases (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    status text DEFAULT 'not_started'::text,
    purchased_at timestamp with time zone DEFAULT now(),
    book_id uuid,
    CONSTRAINT purchases_status_check CHECK ((status = ANY (ARRAY['currently_reading'::text, 'completed'::text, 'not_started'::text])))
);


--
-- Name: pyq_papers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pyq_papers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    subject_id uuid,
    year integer NOT NULL,
    type public.pyq_paper_type NOT NULL,
    title text NOT NULL,
    file_url text NOT NULL,
    file_size text,
    created_at timestamp with time zone DEFAULT now(),
    file_path text
);


--
-- Name: pyq_subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pyq_subjects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text,
    description text,
    format text,
    file_url text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: revenue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.revenue (
    id bigint NOT NULL,
    amount numeric,
    created_at timestamp without time zone DEFAULT now(),
    user_id uuid,
    item_type text,
    old_item_id integer,
    item_id uuid,
    payment_id uuid
);


--
-- Name: revenue_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.revenue ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.revenue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    permissions text[] DEFAULT '{}'::text[],
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: saved_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_jobs (
    id bigint NOT NULL,
    user_id uuid,
    job_id bigint,
    saved_at timestamp without time zone DEFAULT now()
);


--
-- Name: saved_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_jobs_id_seq OWNED BY public.saved_jobs.id;


--
-- Name: study_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.study_notes (
    id integer NOT NULL,
    folder_id integer,
    title text,
    file_path text,
    file_name text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    subject_id integer,
    uploaded_by uuid
);


--
-- Name: study_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.study_notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: study_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.study_notes_id_seq OWNED BY public.study_notes.id;


--
-- Name: study_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.study_sessions (
    id bigint NOT NULL,
    user_id uuid,
    duration numeric,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: study_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.study_sessions ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.study_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subjects (
    id bigint NOT NULL,
    value text NOT NULL,
    label text NOT NULL
);


--
-- Name: subjects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subjects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subjects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subjects_id_seq OWNED BY public.subjects.id;


--
-- Name: submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.submissions (
    id integer NOT NULL,
    exam_id integer,
    user_id uuid NOT NULL,
    answer_text text,
    answer_file_path text,
    answer_file_name text,
    submitted_at timestamp with time zone DEFAULT now(),
    score integer,
    admin_message text
);


--
-- Name: submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.submissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.submissions_id_seq OWNED BY public.submissions.id;


--
-- Name: subscription_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_plans (
    id bigint NOT NULL,
    slug text NOT NULL,
    name text NOT NULL,
    price numeric NOT NULL,
    period text NOT NULL,
    features jsonb,
    popular boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: subscription_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.subscription_plans ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.subscription_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id bigint NOT NULL,
    user_id uuid,
    plan text,
    amount numeric,
    created_at timestamp without time zone DEFAULT now(),
    status text DEFAULT 'active'::text,
    end_date timestamp with time zone
);


--
-- Name: subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.subscriptions ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: system_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform_name text DEFAULT 'AcademicHub'::text,
    support_email text DEFAULT 'support@academichub.com'::text,
    support_phone text DEFAULT '+1 (555) 123-4567'::text,
    default_currency text DEFAULT 'USD'::text,
    registrations_enabled boolean DEFAULT true,
    uploads_enabled boolean DEFAULT true,
    maintenance_mode boolean DEFAULT false,
    backup_retention_days integer DEFAULT 30,
    last_backup timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: test_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_attempts (
    id integer NOT NULL,
    user_id uuid,
    test_id integer,
    answers jsonb DEFAULT '{}'::jsonb,
    completed_questions integer DEFAULT 0,
    score integer,
    rank integer,
    started_at timestamp with time zone DEFAULT now(),
    completed_at timestamp with time zone
);


--
-- Name: test_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.test_attempts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: test_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.test_attempts_id_seq OWNED BY public.test_attempts.id;


--
-- Name: test_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_results (
    id bigint NOT NULL,
    user_id uuid,
    test_id bigint,
    score numeric,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: test_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.test_results ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.test_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_activity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_activity (
    id bigint NOT NULL,
    user_id uuid,
    action text,
    type text,
    details text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.user_activity ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.user_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_books (
    id bigint NOT NULL,
    user_id uuid,
    progress integer DEFAULT 0,
    status text,
    updated_at timestamp with time zone DEFAULT now(),
    book_id uuid NOT NULL,
    CONSTRAINT user_books_status_check CHECK ((status = ANY (ARRAY['reading'::text, 'completed'::text, 'paused'::text])))
);


--
-- Name: user_books_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.user_books ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.user_books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_cart; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_cart (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    book_id uuid,
    note_id bigint,
    quantity integer DEFAULT 1,
    added_at timestamp with time zone DEFAULT now(),
    CONSTRAINT cart_item_one_of_two CHECK ((((book_id IS NOT NULL) AND (note_id IS NULL)) OR ((book_id IS NULL) AND (note_id IS NOT NULL))))
);


--
-- Name: user_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_devices (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    fingerprint text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_devices_id_seq OWNED BY public.user_devices.id;


--
-- Name: user_library; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_library (
    id bigint NOT NULL,
    user_id uuid,
    progress integer DEFAULT 0,
    added_at timestamp without time zone DEFAULT now(),
    book_id uuid,
    last_page integer DEFAULT 1,
    completed_at timestamp with time zone
);


--
-- Name: user_library_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_library_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_library_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_library_id_seq OWNED BY public.user_library.id;


--
-- Name: user_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_notifications (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    link text,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.user_notifications ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.user_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_preferences (
    user_id uuid NOT NULL,
    theme text,
    language text,
    timezone text,
    auto_save boolean,
    sync_highlights boolean,
    reading_reminders boolean,
    updated_at timestamp without time zone
);


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profiles (
    user_id uuid NOT NULL,
    first_name text,
    last_name text,
    email text,
    phone text,
    dob date,
    institution text,
    field_of_study text,
    academic_level text,
    bio text,
    avatar_url text,
    language text DEFAULT 'English (US)'::text,
    timezone text DEFAULT 'Eastern Time (ET)'::text,
    theme text DEFAULT 'light'::text,
    auto_save boolean DEFAULT true,
    sync_highlights boolean DEFAULT true,
    reading_reminders boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: user_security; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_security (
    user_id uuid NOT NULL,
    two_factor_enabled boolean DEFAULT false,
    two_factor_method text DEFAULT 'none'::text,
    last_password_change timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    id bigint NOT NULL,
    user_id uuid,
    device_name text,
    browser text,
    location text,
    ip_address text,
    last_active timestamp without time zone DEFAULT now(),
    active boolean DEFAULT true,
    is_current boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    device text,
    user_agent text,
    device_id text NOT NULL,
    expires_at timestamp without time zone
);


--
-- Name: user_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_sessions_id_seq OWNED BY public.user_sessions.id;


--
-- Name: user_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_stats (
    id bigint NOT NULL,
    user_id uuid,
    tests_taken integer DEFAULT 0,
    average_score double precision DEFAULT 0,
    best_rank integer,
    total_study_time double precision DEFAULT 0,
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: user_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_stats_id_seq OWNED BY public.user_stats.id;


--
-- Name: user_streaks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_streaks (
    id bigint NOT NULL,
    user_id uuid,
    streak_days integer DEFAULT 0
);


--
-- Name: user_streaks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.user_streaks ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.user_streaks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    plan_id bigint NOT NULL,
    started_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    status text DEFAULT 'active'::text,
    metadata jsonb
);


--
-- Name: users_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_metadata (
    id uuid NOT NULL,
    name text,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: v_customers; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_customers AS
 SELECT p.id,
    p.full_name,
    p.email,
    p.created_at,
    p.account_status,
    p.role,
    p.first_name,
    p.last_name,
    p.phone,
    p.dob,
    p.institution,
    p.field_of_study,
    p.academic_level,
    p.bio,
    p.avatar_url,
    p.email_notifications,
    p.push_notifications,
    usp.plan_id,
    sp.name AS subscription_plan,
    usp.status AS subscription_status,
    usp.started_at AS subscription_start_date,
    usp.expires_at AS subscription_end_date,
        CASE
            WHEN (sp.name ~~* '%monthly%'::text) THEN 'monthly'::text
            WHEN (sp.name ~~* '%annual%'::text) THEN 'annually'::text
            ELSE 'free'::text
        END AS billing_status,
    COALESCE(( SELECT sum(r.amount) AS sum
           FROM public.revenue r
          WHERE (r.user_id = p.id)), (0)::numeric) AS total_spent
   FROM ((public.profiles p
     LEFT JOIN LATERAL ( SELECT user_subscriptions.id,
            user_subscriptions.user_id,
            user_subscriptions.plan_id,
            user_subscriptions.started_at,
            user_subscriptions.expires_at,
            user_subscriptions.status,
            user_subscriptions.metadata
           FROM public.user_subscriptions
          WHERE (user_subscriptions.user_id = p.id)
          ORDER BY user_subscriptions.started_at DESC
         LIMIT 1) usp ON (true))
     LEFT JOIN public.subscription_plans sp ON ((usp.plan_id = sp.id)));


--
-- Name: watermark_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watermark_jobs (
    id bigint NOT NULL,
    book_id uuid,
    status text DEFAULT 'queued'::text,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: watermark_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.watermark_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: watermark_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.watermark_jobs_id_seq OWNED BY public.watermark_jobs.id;


--
-- Name: writing_feedback; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.writing_feedback (
    id bigint NOT NULL,
    order_id bigint,
    user_id uuid,
    writer_name text,
    message text NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    user_name text,
    sender text DEFAULT 'user'::text,
    read_by_admin boolean DEFAULT false
);


--
-- Name: writing_feedback_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.writing_feedback_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: writing_feedback_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.writing_feedback_id_seq OWNED BY public.writing_feedback.id;


--
-- Name: writing_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.writing_orders (
    id bigint NOT NULL,
    user_id uuid,
    title text NOT NULL,
    type text NOT NULL,
    subject_area text,
    academic_level text,
    pages integer,
    deadline date,
    status text DEFAULT 'Pending'::text,
    progress integer DEFAULT 0,
    total_price numeric(8,2) DEFAULT 0,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    author_id uuid,
    accepted_at timestamp with time zone,
    completed_at timestamp with time zone,
    notes_url text,
    rejection_reason text,
    final_text text,
    rejected_at timestamp without time zone,
    user_name text,
    attachments_url text,
    instructions text,
    paid_at timestamp with time zone,
    payment_success boolean DEFAULT false,
    payment_status text DEFAULT 'Pending'::text,
    order_temp_id bigint,
    additional_notes text,
    updated_by uuid,
    updated_by_name text,
    user_updated_at timestamp with time zone,
    user_updated_notes text,
    admin_updated_at timestamp with time zone,
    admin_updated_by uuid
);


--
-- Name: writing_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.writing_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: writing_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.writing_orders_id_seq OWNED BY public.writing_orders.id;


--
-- Name: writing_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.writing_services (
    id bigint NOT NULL,
    name text NOT NULL,
    description text,
    turnaround text,
    base_price numeric(8,2),
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: writing_services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.writing_services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: writing_services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.writing_services_id_seq OWNED BY public.writing_services.id;


--
-- Name: exams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exams ALTER COLUMN id SET DEFAULT nextval('public.exams_id_seq'::regclass);


--
-- Name: folders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders ALTER COLUMN id SET DEFAULT nextval('public.folders_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs ALTER COLUMN id SET DEFAULT nextval('public.jobs_id_seq'::regclass);


--
-- Name: mock_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_attempts ALTER COLUMN id SET DEFAULT nextval('public.mock_attempts_id_seq'::regclass);


--
-- Name: mock_test_questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_test_questions ALTER COLUMN id SET DEFAULT nextval('public.mock_test_questions_id_seq'::regclass);


--
-- Name: notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes ALTER COLUMN id SET DEFAULT nextval('public.notes_id_seq'::regclass);


--
-- Name: saved_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_jobs ALTER COLUMN id SET DEFAULT nextval('public.saved_jobs_id_seq'::regclass);


--
-- Name: study_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_notes ALTER COLUMN id SET DEFAULT nextval('public.study_notes_id_seq'::regclass);


--
-- Name: subjects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects ALTER COLUMN id SET DEFAULT nextval('public.subjects_id_seq'::regclass);


--
-- Name: submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions ALTER COLUMN id SET DEFAULT nextval('public.submissions_id_seq'::regclass);


--
-- Name: test_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts ALTER COLUMN id SET DEFAULT nextval('public.test_attempts_id_seq'::regclass);


--
-- Name: user_devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices ALTER COLUMN id SET DEFAULT nextval('public.user_devices_id_seq'::regclass);


--
-- Name: user_library id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_library ALTER COLUMN id SET DEFAULT nextval('public.user_library_id_seq'::regclass);


--
-- Name: user_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions ALTER COLUMN id SET DEFAULT nextval('public.user_sessions_id_seq'::regclass);


--
-- Name: user_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats ALTER COLUMN id SET DEFAULT nextval('public.user_stats_id_seq'::regclass);


--
-- Name: watermark_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watermark_jobs ALTER COLUMN id SET DEFAULT nextval('public.watermark_jobs_id_seq'::regclass);


--
-- Name: writing_feedback id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_feedback ALTER COLUMN id SET DEFAULT nextval('public.writing_feedback_id_seq'::regclass);


--
-- Name: writing_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_orders ALTER COLUMN id SET DEFAULT nextval('public.writing_orders_id_seq'::regclass);


--
-- Name: writing_services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_services ALTER COLUMN id SET DEFAULT nextval('public.writing_services_id_seq'::regclass);


--
-- Data for Name: activity_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.activity_log (id, user_name, action, type, created_at, user_id) FROM stdin;
434	Jarardh  C	logged in	login	2025-12-05 06:56:47.583958	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
437	Jarardh  C	logged in	login	2025-12-05 08:29:49.462087	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
441	Jarardh  C	logged in	login	2025-12-05 09:16:43.081318	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
444	Jarardh  C	logged in	login	2025-12-05 11:18:40.744768	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
447	Jarardh  C	logged in	login	2025-12-05 11:54:03.436657	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
450	Jarardh  C	logged in	login	2025-12-06 03:22:07.684796	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
453	Jarardh  C	logged in	login	2025-12-06 05:45:51.399349	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
848	Kevin Jo	created an account	activity	2026-01-12 03:26:07.549631	f8433f32-428c-4011-8cd0-64ce50fca8f9
459	harith	logged in	login	2025-12-06 07:11:02.392563	782c37df-f571-4390-bd69-fefdb0e13cf5
462	Jarardh  C	logged in	login	2025-12-06 08:24:20.456715	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
465	Jarardh  C	logged in	login	2025-12-06 08:30:05.977815	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
468	Jarardh  C	logged in	login	2025-12-06 10:17:17.154649	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
474	Jarardh  C	logged in	login	2025-12-08 04:13:29.502482	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
475	Jarardh  C	logged in	login	2025-12-08 04:14:08.121079	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
478	harith	logged in	login	2025-12-08 05:15:16.667539	782c37df-f571-4390-bd69-fefdb0e13cf5
484	harith	logged in	login	2025-12-08 06:11:36.723019	782c37df-f571-4390-bd69-fefdb0e13cf5
492	Jarardh  C	logged in	login	2025-12-08 06:25:33.27284	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
508	harith	logged in	login	2025-12-08 09:35:49.887689	782c37df-f571-4390-bd69-fefdb0e13cf5
518	Jarardh  C	logged in	login	2025-12-08 11:50:34.404569	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
527	harith	logged in	login	2025-12-10 04:23:52.277454	782c37df-f571-4390-bd69-fefdb0e13cf5
531	Jarardh  C	logged in	login	2025-12-10 04:36:56.14343	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
538	Jarardh  C	logged in	login	2025-12-10 05:45:37.257981	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
550	harith	logged in	login	2025-12-11 03:22:58.552139	782c37df-f571-4390-bd69-fefdb0e13cf5
553	harith	logged in	login	2025-12-11 04:26:23.018734	782c37df-f571-4390-bd69-fefdb0e13cf5
556	Jarardh  C	logged in	login	2025-12-11 04:49:02.784273	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
559	Jarardh  C	logged in	login	2025-12-11 05:51:18.711947	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
562	Jarardh  C	logged in	login	2025-12-11 06:38:25.60104	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
569	Jarardh  C	logged in	login	2025-12-12 03:25:52.526956	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
579	harith	logged in	login	2025-12-12 05:41:20.8497	782c37df-f571-4390-bd69-fefdb0e13cf5
580	harith	logged in	login	2025-12-12 05:41:52.506342	782c37df-f571-4390-bd69-fefdb0e13cf5
583	harith	logged in	login	2025-12-12 08:19:25.324696	782c37df-f571-4390-bd69-fefdb0e13cf5
586	Jarardh  C	logged in	login	2025-12-12 08:31:12.14563	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
589	harith	logged in	login	2025-12-12 09:15:18.428013	782c37df-f571-4390-bd69-fefdb0e13cf5
592	harith	logged in	login	2025-12-12 10:20:47.971613	782c37df-f571-4390-bd69-fefdb0e13cf5
595	Jarardh  C	logged in	login	2025-12-12 11:27:44.972989	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
604	Jarardh  C	logged in	login	2025-12-13 10:50:48.657594	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
607	Jarardh  C	logged in	login	2025-12-14 12:21:41.037398	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
613	Jarardh  C	logged in	login	2025-12-15 05:57:16.416896	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
625	Jarardh  C	logged in	login	2025-12-15 09:12:56.935193	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
639	Jarardh  C	logged in	login	2025-12-16 05:09:25.327682	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
651	harith	logged in	login	2025-12-16 05:42:35.720557	782c37df-f571-4390-bd69-fefdb0e13cf5
657	Jarardh  C	logged in	login	2025-12-16 08:25:24.594444	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
663	Jarardh  C	logged in	login	2025-12-16 11:17:12.126334	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
672	Jarardh  C	logged in	login	2025-12-17 09:29:41.128624	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
678	Jarardh  C	logged in	login	2025-12-17 10:07:03.412637	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
681	Jarardh  C	logged in	login	2025-12-17 10:21:42.149917	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
684	Jarardh  C	logged in	login	2025-12-17 11:25:37.662163	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
688	Jarardh  C	logged in	login	2025-12-17 11:52:50.822494	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
691	Jarardh  C	logged in	login	2025-12-18 03:23:11.627648	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
694	Jarardh  C	logged in	login	2025-12-18 03:51:44.759767	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
697	Jarardh  C	logged in	login	2025-12-18 04:03:41.576784	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
700	Jarardh  C	logged in	login	2025-12-18 04:09:56.510614	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
703	Jarardh  C	logged in	login	2025-12-18 04:31:44.297397	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
706	harith	logged in	login	2025-12-18 04:44:56.821594	782c37df-f571-4390-bd69-fefdb0e13cf5
712	Jarardh  C	logged in	login	2025-12-18 08:22:24.925911	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
715	Jarardh  C	logged in	login	2025-12-18 09:15:27.571172	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
718	Jarardh  C	logged in	login	2025-12-18 10:22:11.725797	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
721	Jarardh  C	logged in	login	2025-12-19 05:10:59.108712	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
725	Jarardh  C	logged in	login	2025-12-19 05:36:50.362176	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
728	Jarardh  C	logged in	login	2025-12-19 08:18:31.980823	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
731	Jarardh  C	logged in	login	2025-12-19 09:15:43.281522	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
736	Jarardh  C	logged in	login	2025-12-19 09:37:15.459732	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
738	harith	logged in	login	2025-12-19 11:19:39.415924	782c37df-f571-4390-bd69-fefdb0e13cf5
741	Jarardh  C	logged in	login	2025-12-20 03:21:39.587928	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
435	Jarardh  C	logged in	login	2025-12-05 07:01:24.391839	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
438	Jarardh  C	logged in	login	2025-12-05 08:32:40.921618	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
439	Jarardh  C	logged in	login	2025-12-05 08:33:04.089538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
442	Jarardh  C	logged in	login	2025-12-05 09:21:19.565772	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
445	Jarardh  C	logged in	login	2025-12-05 11:24:04.346056	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
448	Jarardh  C	logged in	login	2025-12-05 11:59:30.484127	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
451	Jarardh  C	logged in	login	2025-12-06 04:22:13.273109	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
454	Jarardh  C	logged in	login	2025-12-06 05:54:40.024869	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
460	harith	logged in	login	2025-12-06 08:20:36.836274	782c37df-f571-4390-bd69-fefdb0e13cf5
466	harith	logged in	login	2025-12-06 09:34:57.181585	782c37df-f571-4390-bd69-fefdb0e13cf5
469	Jarardh  C	logged in	login	2025-12-06 10:20:00.274274	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
472	harith	logged in	login	2025-12-08 04:04:28.132562	782c37df-f571-4390-bd69-fefdb0e13cf5
476	harith	logged in	login	2025-12-08 04:17:14.175996	782c37df-f571-4390-bd69-fefdb0e13cf5
479	harith	logged in	login	2025-12-08 05:26:51.933723	782c37df-f571-4390-bd69-fefdb0e13cf5
487	Jarardh  C	logged in	login	2025-12-08 06:15:04.783395	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
496	harith	logged in	login	2025-12-08 06:42:05.611597	782c37df-f571-4390-bd69-fefdb0e13cf5
499	Jarardh  C	logged in	login	2025-12-08 07:13:38.418715	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
502	harith	logged in	login	2025-12-08 08:20:06.309267	782c37df-f571-4390-bd69-fefdb0e13cf5
516	Jarardh  C	logged in	login	2025-12-08 11:35:27.138156	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
525	harith	logged in	login	2025-12-10 03:42:07.129428	782c37df-f571-4390-bd69-fefdb0e13cf5
532	harith	logged in	login	2025-12-10 04:40:25.723902	782c37df-f571-4390-bd69-fefdb0e13cf5
534	harith	logged in	login	2025-12-10 04:41:26.140607	782c37df-f571-4390-bd69-fefdb0e13cf5
536	harith	logged in	login	2025-12-10 04:47:00.834832	782c37df-f571-4390-bd69-fefdb0e13cf5
539	harith	logged in	login	2025-12-10 06:46:53.973151	782c37df-f571-4390-bd69-fefdb0e13cf5
542	harith	logged in	login	2025-12-10 08:18:56.665613	782c37df-f571-4390-bd69-fefdb0e13cf5
545	harith	logged in	login	2025-12-10 08:38:57.919308	782c37df-f571-4390-bd69-fefdb0e13cf5
548	harith	logged in	login	2025-12-10 11:18:21.485721	782c37df-f571-4390-bd69-fefdb0e13cf5
554	harith	logged in	login	2025-12-11 04:27:24.219167	782c37df-f571-4390-bd69-fefdb0e13cf5
557	harith	logged in	login	2025-12-11 05:33:22.537577	782c37df-f571-4390-bd69-fefdb0e13cf5
560	Jarardh  C	logged in	login	2025-12-11 06:30:59.563568	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
563	Jarardh  C	logged in	login	2025-12-11 06:40:33.048711	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
566	harith	logged in	login	2025-12-11 08:15:24.340082	782c37df-f571-4390-bd69-fefdb0e13cf5
567	harith	logged in	login	2025-12-11 08:16:17.289744	782c37df-f571-4390-bd69-fefdb0e13cf5
570	harith	logged in	login	2025-12-12 03:28:06.243351	782c37df-f571-4390-bd69-fefdb0e13cf5
574	Jarardh  C	logged in	login	2025-12-12 04:15:15.520909	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
577	harith	logged in	login	2025-12-12 05:35:26.258982	782c37df-f571-4390-bd69-fefdb0e13cf5
581	harith	logged in	login	2025-12-12 05:43:21.133443	782c37df-f571-4390-bd69-fefdb0e13cf5
584	harith	logged in	login	2025-12-12 08:26:27.430852	782c37df-f571-4390-bd69-fefdb0e13cf5
587	harith	logged in	login	2025-12-12 09:08:37.966255	782c37df-f571-4390-bd69-fefdb0e13cf5
590	harith	logged in	login	2025-12-12 09:34:34.287529	782c37df-f571-4390-bd69-fefdb0e13cf5
593	harith	logged in	login	2025-12-12 11:25:00.555357	782c37df-f571-4390-bd69-fefdb0e13cf5
605	harith	logged in	login	2025-12-13 11:48:21.351108	782c37df-f571-4390-bd69-fefdb0e13cf5
608	harith	logged in	login	2025-12-15 03:45:50.238278	782c37df-f571-4390-bd69-fefdb0e13cf5
611	harith	logged in	login	2025-12-15 04:48:55.049616	782c37df-f571-4390-bd69-fefdb0e13cf5
620	Jarardh  C	logged in	login	2025-12-15 08:39:22.070464	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
146	Jarardh  C	created an account	activity	2025-11-24 06:03:00.712041	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
623	Jarardh  C	logged in	login	2025-12-15 09:00:12.17434	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
630	Jarardh  C	logged in	login	2025-12-15 09:29:38.769061	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
637	Jarardh  C	logged in	login	2025-12-16 05:03:31.941714	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
661	Jarardh  C	logged in	login	2025-12-16 10:25:09.441126	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
664	Jarardh  C	logged in	login	2025-12-16 11:19:53.149889	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
667	Jarardh  C	logged in	login	2025-12-17 03:56:33.610384	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
670	Jarardh  C	logged in	login	2025-12-17 07:18:05.885819	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
673	Jarardh  C	logged in	login	2025-12-17 09:32:13.655129	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
676	Jarardh  C	logged in	login	2025-12-17 10:05:28.017477	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
679	Jarardh  C	logged in	login	2025-12-17 10:10:50.986527	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
682	Jarardh  C	logged in	login	2025-12-17 10:25:28.812957	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
685	Jarardh  C	logged in	login	2025-12-17 11:28:00.506421	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
686	Jarardh  C	logged in	login	2025-12-17 11:28:21.283711	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
689	Jarardh  C	logged in	login	2025-12-17 11:56:36.60911	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
692	Jarardh  C	logged in	login	2025-12-18 03:44:38.933349	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
695	Jarardh  C	logged in	login	2025-12-18 03:58:26.100284	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
698	Jarardh  C	logged in	login	2025-12-18 04:05:45.937503	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
701	Jarardh  C	logged in	login	2025-12-18 04:13:42.578638	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
704	Jarardh  C	logged in	login	2025-12-18 04:37:38.492382	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
707	harith	logged in	login	2025-12-18 04:49:30.730287	782c37df-f571-4390-bd69-fefdb0e13cf5
710	harith	logged in	login	2025-12-18 04:59:31.230798	782c37df-f571-4390-bd69-fefdb0e13cf5
713	Jarardh  C	logged in	login	2025-12-18 08:22:38.83387	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
716	Jarardh  C	logged in	login	2025-12-18 10:13:48.760084	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
719	Jarardh  C	logged in	login	2025-12-19 03:35:50.990461	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
722	Jarardh  C	logged in	login	2025-12-19 05:29:26.057969	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
726	Jarardh  C	logged in	login	2025-12-19 05:37:53.243196	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
733	Jarardh  C	logged in	login	2025-12-19 09:18:39.919454	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
436	Jarardh  C	logged in	login	2025-12-05 08:23:44.541454	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
440	Jarardh  C	logged in	login	2025-12-05 08:34:19.873887	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
443	Jarardh  C	logged in	login	2025-12-05 10:20:00.57217	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
446	Jarardh  C	logged in	login	2025-12-05 11:26:04.559998	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
449	Jarardh  C	logged in	login	2025-12-06 03:20:27.646651	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
452	harith	logged in	login	2025-12-06 05:40:48.128924	782c37df-f571-4390-bd69-fefdb0e13cf5
455	Jarardh  C	logged in	login	2025-12-06 06:13:22.948915	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
458	harith	logged in	login	2025-12-06 06:41:09.135648	782c37df-f571-4390-bd69-fefdb0e13cf5
461	Jarardh  C	logged in	login	2025-12-06 08:22:14.9371	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
464	Jarardh  C	logged in	login	2025-12-06 08:27:28.69496	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
467	Jarardh  C	logged in	login	2025-12-06 10:10:07.977591	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
470	harith	logged in	login	2025-12-06 10:45:58.388619	782c37df-f571-4390-bd69-fefdb0e13cf5
473	Jarardh  C	logged in	login	2025-12-08 04:09:16.556497	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
477	Jarardh  C	logged in	login	2025-12-08 04:49:45.257337	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
480	Jarardh  C	logged in	login	2025-12-08 06:06:10.986421	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
483	harith	logged in	login	2025-12-08 06:09:50.361939	782c37df-f571-4390-bd69-fefdb0e13cf5
486	harith	logged in	login	2025-12-08 06:14:36.557666	782c37df-f571-4390-bd69-fefdb0e13cf5
500	Jarardh  C	logged in	login	2025-12-08 08:16:51.528293	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
510	harith	logged in	login	2025-12-08 11:10:25.463144	782c37df-f571-4390-bd69-fefdb0e13cf5
517	Jarardh  C	logged in	login	2025-12-08 11:48:04.269266	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
533	harith	logged in	login	2025-12-10 04:41:03.292765	782c37df-f571-4390-bd69-fefdb0e13cf5
537	harith	logged in	login	2025-12-10 04:53:02.128849	782c37df-f571-4390-bd69-fefdb0e13cf5
540	harith	logged in	login	2025-12-10 08:11:42.364014	782c37df-f571-4390-bd69-fefdb0e13cf5
543	harith	logged in	login	2025-12-10 08:28:27.56407	782c37df-f571-4390-bd69-fefdb0e13cf5
546	harith	logged in	login	2025-12-10 09:41:35.963171	782c37df-f571-4390-bd69-fefdb0e13cf5
549	Jarardh  C	logged in	login	2025-12-10 11:48:22.008273	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
552	harith	logged in	login	2025-12-11 04:24:50.679041	782c37df-f571-4390-bd69-fefdb0e13cf5
558	harith	logged in	login	2025-12-11 05:50:44.184106	782c37df-f571-4390-bd69-fefdb0e13cf5
561	Jarardh  C	logged in	login	2025-12-11 06:34:25.393061	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
568	harith	logged in	login	2025-12-11 08:17:41.474646	782c37df-f571-4390-bd69-fefdb0e13cf5
571	Jarardh  C	logged in	login	2025-12-12 03:38:53.113058	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
575	harith	logged in	login	2025-12-12 05:01:34.879759	782c37df-f571-4390-bd69-fefdb0e13cf5
578	Jarardh  C	logged in	login	2025-12-12 05:39:59.742343	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
582	harith	logged in	login	2025-12-12 08:12:48.519525	782c37df-f571-4390-bd69-fefdb0e13cf5
585	harith	logged in	login	2025-12-12 08:30:12.295044	782c37df-f571-4390-bd69-fefdb0e13cf5
588	harith	logged in	login	2025-12-12 09:09:11.710242	782c37df-f571-4390-bd69-fefdb0e13cf5
591	harith	logged in	login	2025-12-12 09:36:01.63976	782c37df-f571-4390-bd69-fefdb0e13cf5
594	harith	logged in	login	2025-12-12 11:26:33.445162	782c37df-f571-4390-bd69-fefdb0e13cf5
603	harith	logged in	login	2025-12-13 10:40:00.451523	782c37df-f571-4390-bd69-fefdb0e13cf5
606	harith	logged in	login	2025-12-13 12:51:43.956012	782c37df-f571-4390-bd69-fefdb0e13cf5
627	Jarardh  C	logged in	login	2025-12-15 09:18:04.104452	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
650	Jarardh  C	logged in	login	2025-12-16 05:35:01.092444	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
659	Jarardh  C	logged in	login	2025-12-16 09:46:01.294347	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
662	Jarardh  C	logged in	login	2025-12-16 11:14:21.164108	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
665	Jarardh  C	logged in	login	2025-12-16 11:35:43.225501	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
671	Jarardh  C	logged in	login	2025-12-17 08:35:27.25887	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
674	Jarardh  C	logged in	login	2025-12-17 09:33:40.477656	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
677	Jarardh  C	logged in	login	2025-12-17 10:06:25.039091	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
680	Jarardh  C	logged in	login	2025-12-17 10:11:53.065852	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
683	Jarardh  C	logged in	login	2025-12-17 11:20:35.701117	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
687	Jarardh  C	logged in	login	2025-12-17 11:36:03.830563	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
690	Jarardh  C	logged in	login	2025-12-18 01:52:16.400768	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
693	Jarardh  C	logged in	login	2025-12-18 03:47:28.407229	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
696	Jarardh  C	logged in	login	2025-12-18 04:01:32.68933	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
699	Jarardh  C	logged in	login	2025-12-18 04:07:51.418653	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
702	Jarardh  C	logged in	login	2025-12-18 04:22:40.572077	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
705	harith	logged in	login	2025-12-18 04:40:52.9748	782c37df-f571-4390-bd69-fefdb0e13cf5
708	harith	logged in	login	2025-12-18 04:55:00.713113	782c37df-f571-4390-bd69-fefdb0e13cf5
711	harith	logged in	login	2025-12-18 05:18:52.857812	782c37df-f571-4390-bd69-fefdb0e13cf5
714	Jarardh  C	logged in	login	2025-12-18 08:24:26.905027	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
717	Jarardh  C	logged in	login	2025-12-18 10:18:35.13703	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
720	Jarardh  C	logged in	login	2025-12-19 04:39:10.952656	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
723	Jarardh  C	logged in	login	2025-12-19 05:31:43.874992	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
724	Jarardh  C	logged in	login	2025-12-19 05:34:19.500838	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
727	Jarardh  C	logged in	login	2025-12-19 08:18:26.179444	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
730	Jarardh  C	logged in	login	2025-12-19 08:55:26.411696	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
734	Jarardh  C	logged in	login	2025-12-19 09:25:33.201536	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
735	harith	logged in	login	2025-12-19 09:28:08.061946	782c37df-f571-4390-bd69-fefdb0e13cf5
737	Jarardh  C	logged in	login	2025-12-19 11:13:10.908577	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
740	Jarardh  C	logged in	login	2025-12-20 03:18:47.884285	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
744	Jarardh  C	logged in	login	2025-12-20 04:17:08.211639	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
747	Jarardh  C	logged in	login	2025-12-20 04:24:03.864314	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
748	Jarardh  C	logged in	login	2025-12-20 04:27:28.360849	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
749	Jarardh  C	logged in	login	2025-12-20 04:28:03.482654	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
750	Jarardh  C	logged in	login	2025-12-20 04:30:48.978894	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
751	Jarardh  C	logged in	login	2025-12-20 04:55:28.743543	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
752	Jarardh  C	logged in	login	2025-12-20 05:47:00.614561	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
753	Jarardh  C	logged in	login	2025-12-20 05:57:03.583706	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
755	Jarardh  C	logged in	login	2025-12-22 03:33:32.591503	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
756	john  cena	created an account	activity	2025-12-22 03:34:49.290139	15b86823-e23d-4b66-b066-041f89726885
760	Jarardh  C	logged in	login	2025-12-22 03:39:47.393454	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
761	Jarardh  C	logged in	login	2025-12-22 03:55:15.270474	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
763	Jarardh  C	logged in	login	2025-12-22 04:08:06.708703	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
764	Jarardh  C	logged in	login	2025-12-22 04:31:45.462516	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
765	Jarardh  C	logged in	login	2025-12-22 04:32:00.105436	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
766	Jarardh  C	logged in	login	2025-12-22 04:32:27.653815	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
767	Jarardh  C	logged in	login	2025-12-22 04:34:35.543257	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
768	Jarardh  C	logged in	login	2025-12-22 04:35:09.754095	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
769	Jarardh  C	logged in	login	2025-12-22 04:43:09.685637	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
770	Jarardh  C	logged in	login	2025-12-22 05:16:00.488337	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
771	Jarardh  C	logged in	login	2025-12-22 05:36:20.543665	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
772	Jarardh  C	logged in	login	2025-12-22 06:06:53.850242	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
773	Jarardh  C	logged in	login	2025-12-22 06:13:05.650352	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
774	Jarardh  C	logged in	login	2025-12-22 06:39:17.457741	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
775	harith	logged in	login	2025-12-22 07:17:02.549725	782c37df-f571-4390-bd69-fefdb0e13cf5
776	Jarardh  C	logged in	login	2025-12-22 08:29:06.82133	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
777	harith	logged in	login	2025-12-22 08:32:08.262836	782c37df-f571-4390-bd69-fefdb0e13cf5
778	harith	logged in	login	2025-12-22 08:34:10.348088	782c37df-f571-4390-bd69-fefdb0e13cf5
779	Jarardh  C	logged in	login	2025-12-22 08:42:24.038558	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
780	Jarardh  C	logged in	login	2025-12-22 09:04:35.729093	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
781	Jarardh  C	logged in	login	2025-12-22 09:08:16.764849	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
782	Jarardh  C	logged in	login	2025-12-22 09:13:31.093783	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
783	Jarardh  C	logged in	login	2025-12-22 09:15:39.800988	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
784	Jarardh  C	logged in	login	2025-12-22 09:24:04.640593	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
785	Jarardh  C	logged in	login	2025-12-22 09:33:29.729691	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
786	Jarardh  C	logged in	login	2025-12-22 09:51:52.84966	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
787	Jarardh  C	logged in	login	2025-12-22 10:02:39.617648	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
789	Jarardh  C	logged in	login	2025-12-22 10:04:19.072625	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
790	Jarardh  C	logged in	login	2025-12-22 10:18:20.324638	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
791	Jarardh Jacob  C	logged in	login	2025-12-22 10:20:51.118004	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
792	Jarardh Jacob  C	logged in	login	2025-12-22 10:22:00.28434	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
793	Jarardh Jacob  C	logged in	login	2025-12-22 10:27:22.03056	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
794	Jarardh Jacob  C	logged in	login	2025-12-22 11:16:46.999533	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
795	Jarardh Jacob  C	logged in	login	2025-12-22 11:17:20.457197	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
796	Jarardh Jacob  C	logged in	login	2025-12-22 11:23:22.633625	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
798	anandhu prasad	created an account	activity	2025-12-22 11:45:15.271662	2ce680b9-b205-453c-aa90-cc03a364dc66
799	Jarardh Jacob  C	logged in	login	2025-12-23 03:28:33.160435	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
807	jjj ppp	created an account	activity	2025-12-23 04:11:55.779672	13644e4b-6630-49db-bf9e-fc20e6975c51
808	name name	created an account	activity	2025-12-23 04:17:48.458154	851489c8-56a3-4737-8abc-d695fc0e2618
809	1 1	created an account	activity	2025-12-23 04:23:48.645268	835276a4-f715-4562-8d90-4c6d58e8a508
810	zxcv cv	created an account	activity	2025-12-23 04:24:47.252924	417bc17f-224f-4cca-8fd0-a70c96cde985
811	zxcv cv	logged in	login	2025-12-23 04:25:04.848876	417bc17f-224f-4cca-8fd0-a70c96cde985
814	Jarardh Jacob  C	logged in	login	2025-12-23 04:43:59.765167	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
815	Jarardh Jacob  C	logged in	login	2025-12-23 04:47:11.075907	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
816	Jarardh Jacob  C	logged in	login	2025-12-23 05:06:19.045604	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
817	Jarardh Jacob  C	logged in	login	2025-12-23 05:47:13.54511	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
819	Jarardh Jacob  C	logged in	login	2025-12-23 06:53:07.257169	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
820	Jarardh Jacob  C	logged in	login	2025-12-23 08:22:09.913701	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
821	harith	logged in	login	2025-12-23 08:57:38.926202	782c37df-f571-4390-bd69-fefdb0e13cf5
822	Jarardh Jacob  C	logged in	login	2025-12-23 09:01:50.250623	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
823	Jarardh Jacob  C	logged in	login	2025-12-23 09:05:32.9333	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
825	Jarardh Jacob  C	logged in	login	2025-12-23 09:12:52.918366	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
826	Jarardh Jacob  C	logged in	login	2025-12-23 09:21:14.115563	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
827	Jarardh Jacob  C	logged in	login	2025-12-23 09:23:22.320716	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
828	Jarardh Jacob  C	logged in	login	2025-12-23 09:24:00.409822	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
829	Jarardh Jacob  C	logged in	login	2025-12-23 09:24:57.145886	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
830	Jarardh Jacob  C	logged in	login	2025-12-23 09:29:45.27449	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
831	Jarardh Jacob  C	logged in	login	2025-12-23 09:34:03.903378	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
832	Jarardh Jacob  C	logged in	login	2025-12-23 09:36:46.994575	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
833	Jarardh Jacob  C	logged in	login	2025-12-23 09:38:04.978088	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
834	Jarardh Jacob  C	logged in	login	2025-12-23 09:40:01.248387	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
835	Jarardh Jacob  C	logged in	login	2025-12-23 09:42:00.55823	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
837	Jarardh Jacob  C	logged in	login	2025-12-23 09:44:43.936675	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
838	Jarardh Jacob  C	logged in	login	2025-12-23 09:45:35.318265	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
839	Jarardh Jacob  C	logged in	login	2025-12-23 09:50:08.483434	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
841	Jarardh Jacob  C	logged in	login	2025-12-23 10:08:25.90283	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
\.


--
-- Data for Name: ai_activity_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_activity_log (id, action, status, details, created_at, admin_id) FROM stdin;
\.


--
-- Data for Name: ai_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_settings (id, auto_tagging, summary_generation, plagiarism_detection, smart_recommendations, adaptive_learning, smart_search, updated_at) FROM stdin;
1ee20d56-9606-49e8-a7a9-77c1a256db18	t	t	f	t	t	t	2025-11-07 03:30:06.79594+00
\.


--
-- Data for Name: backups; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.backups (id, status, file_url, triggered_by, created_at) FROM stdin;
\.


--
-- Data for Name: book_sales; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.book_sales (user_id, purchased_at, book_id, id) FROM stdin;
7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2026-01-07 09:52:04.663+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	48e75a62-3830-433e-87c6-79f213ea2fc9
f8433f32-428c-4011-8cd0-64ce50fca8f9	2026-01-13 03:37:27.868+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	e16d32c7-9e8d-45e7-ab12-f71a6198e91a
782c37df-f571-4390-bd69-fefdb0e13cf5	2026-02-09 03:34:58.772+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	008489d2-5c14-4aa3-9b3c-c06693673e12
782c37df-f571-4390-bd69-fefdb0e13cf5	2026-02-09 06:50:53.825+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	99376cd1-0fc0-47a0-9b61-b184436cdcbd
f8433f32-428c-4011-8cd0-64ce50fca8f9	2026-02-09 06:57:37.495+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	762b21ad-4936-447e-a72e-8b93e912cb1e
7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2026-02-09 07:14:53.451+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	d54dec20-39ca-4d16-bc25-0598172fc379
cdff310d-1cbf-4803-8c8b-b93195ac374f	2026-02-10 03:22:05.587+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	6f7e8d03-6227-49ef-a1b9-123ca8a0da2f
cdff310d-1cbf-4803-8c8b-b93195ac374f	2026-02-10 03:23:16.266+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	8c4cbe94-371a-47cc-aedd-b3bf1d3dbcd7
\.


--
-- Data for Name: book_views; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.book_views (id, user_id, book_id, created_at) FROM stdin;
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categories (id, name, slug, created_at) FROM stdin;
8342614b-05fa-4d9a-b09a-e09e9d1c9557	Agriculture	agriculture	2026-01-07 09:18:19.594475+00
4dd1b6a1-d85d-4168-bedf-a9dbe1263641	Agri	agri	2026-01-07 11:58:02.928688+00
40939b25-c53a-4b68-8dcd-b56e2134a6b7	Agriculture and	agriculture-and	2026-01-08 08:57:56.351473+00
388f6cc2-6b64-4b6a-981e-7b74d50cd607	test	test	2026-01-08 09:17:57.81575+00
0c9c0a0f-df06-459d-8cd7-658ce9d7e257	asdf	asdf	2026-01-08 10:38:52.963592+00
\.


--
-- Data for Name: collection_books; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.collection_books (id, collection_id, book_id, progress) FROM stdin;
\.


--
-- Data for Name: collections; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.collections (id, user_id, name, created_at) FROM stdin;
ee0c1ae9-cd5a-4aec-bfdc-7d6751d52869	782c37df-f571-4390-bd69-fefdb0e13cf5	New	2026-02-09 04:03:59.356526+00
\.


--
-- Data for Name: current_affairs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.current_affairs (id, title, category, content, tags, importance, status, article_date, article_time, image_url, image_path, created_at, updated_at, views) FROM stdin;
\.


--
-- Data for Name: current_affairs_views; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.current_affairs_views (id, user_id, article_id, viewed_at) FROM stdin;
\.


--
-- Data for Name: downloaded_notes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.downloaded_notes (id, user_id, note_id, downloaded_at) FROM stdin;
\.


--
-- Data for Name: drm_access_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.drm_access_logs (id, user_name, book_title, action, device_info, ip_address, created_at, book_id, user_id) FROM stdin;
71cf126e-b4eb-41cd-8334-98060fe8122e	harith	E book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-01 09:55:51.27+00	e64a1c75-6e28-424b-93c0-91223c72c18f	782c37df-f571-4390-bd69-fefdb0e13cf5
9b520a54-00de-4fdf-aaf1-5672eb6379b3	harith	E book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-01 09:56:49.999+00	e64a1c75-6e28-424b-93c0-91223c72c18f	782c37df-f571-4390-bd69-fefdb0e13cf5
f756ce3b-0042-429b-bfbb-51b0c4ceac07	harith	E book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-01 09:56:57.442+00	e64a1c75-6e28-424b-93c0-91223c72c18f	782c37df-f571-4390-bd69-fefdb0e13cf5
bfa5fda3-5970-4818-b624-dd8ba6a739d4	harith	E book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-01 09:57:06.562+00	e64a1c75-6e28-424b-93c0-91223c72c18f	782c37df-f571-4390-bd69-fefdb0e13cf5
f1c55d80-c213-4aa1-a02a-14edc01de309	harith	E book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-01 09:57:26.599+00	e64a1c75-6e28-424b-93c0-91223c72c18f	782c37df-f571-4390-bd69-fefdb0e13cf5
39f833c7-1aaa-4c8b-bc3a-04dd8f6f9a30	harith	E book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-01 09:59:46.248+00	e64a1c75-6e28-424b-93c0-91223c72c18f	782c37df-f571-4390-bd69-fefdb0e13cf5
bf5b2e42-8d24-4eed-bddf-14534d998fd9	harith	E book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-01 10:05:23.126+00	e64a1c75-6e28-424b-93c0-91223c72c18f	782c37df-f571-4390-bd69-fefdb0e13cf5
050cbffd-6eaa-48e8-97a2-aec179b2f70a	harith	E book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-01 11:49:05.657+00	e64a1c75-6e28-424b-93c0-91223c72c18f	782c37df-f571-4390-bd69-fefdb0e13cf5
033869d5-50e7-4c3a-9fad-63c08dfd287e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-10 08:37:42.487+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9386531a-a02b-45d7-a41f-ba049c068edf	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-10 08:37:46.966+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
57862dc8-aa2c-4c9a-b816-04b4004fdbbe	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-10 08:37:47.024+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
59dc53f7-f3ab-4317-a205-0867b20bb44a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-10 08:37:47.189+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
4003877f-47e3-4780-806f-f162fe2af8d4	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-10 08:37:47.556+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
85ef9b59-1330-4992-af84-7b6ca70da6cb	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-10 08:38:23.738+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
155585d0-30e3-47b1-9993-4409f0717363	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:08:15.435+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
b18ee20e-c561-40cc-b01b-54c315b086c1	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:40.377+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a517c810-b886-4b0d-a84f-04786cecefbc	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:40.682+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
b21a474e-30ed-4c56-8162-db77500d2d65	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:40.799+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
fd891ed8-bf70-4094-b05d-7e3c6714ff40	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:40.821+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
30a72068-ad3d-4376-8351-74b0203d1aa4	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:41.366+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
2fdff0ce-704f-4c0a-8f47-db2ea6444354	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:42.243+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
cbb066b5-418e-4ed4-806f-8c7eb1128013	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:42.545+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
407ef3ec-616d-495e-bf50-01b309b7d77d	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:42.682+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
2485761b-fe1e-4234-b61e-303fd56e3cd4	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:43.288+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
67a6e0ac-5f36-45cb-a9b7-a5ae3d56e784	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:43.626+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9a6725bf-40d5-411c-a162-1b1e11188d45	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:44.075+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
958afa32-c938-42a1-8044-00a3b54bb623	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:44.437+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
719eecfe-0f0f-4fae-8379-348e9e245c93	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:44.847+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
6e5673cf-081f-4439-9c41-c9bbfd90ffc0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:45.144+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
ec63c3b0-54a0-4923-af14-d0d10ef17a93	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:45.652+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a06f50f6-c6d7-4d14-905f-f1f86f7d6f86	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:46.051+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3648bd79-6402-4836-bfd6-a885938c2049	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:46.543+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
26389f5a-8b7e-405f-94b3-f27eb51674d2	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:10:52.464+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
cdac3471-9e1e-4644-99fe-e0f571958403	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:40.627+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
7d0f610b-07b0-496f-a6cc-74e1317af7cd	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:41.751+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
37a3ec43-f4e5-475e-9278-0a7608bbd83c	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:41.754+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c483f1eb-714c-42bc-a3d6-0982b57def34	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:41.907+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3d11eaf1-c0f9-484e-b3a0-f0d69e4203c1	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:42.364+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
93f5cfae-5fd9-4c7e-b5c5-ca7f83290c23	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:42.947+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
068223d0-5910-4b2d-8061-862056c0d032	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:45.352+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f63036d6-c44d-4dff-b011-ac0d650266bf	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:46.549+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
657245d0-629c-43fa-97cc-dd60734cfef4	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:47.175+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9079910a-c7b0-4c85-b3f2-dab6883f57a2	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:48.364+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
dda98f26-eee2-46b3-a0dc-d4cad40a5779	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:52.436+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f627bff4-1b7e-4e6e-b156-66eab627cce8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:53.801+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
75129e67-7dfd-4812-8cd3-34a773357966	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:59.071+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
60d3fbf4-e251-4145-a3d8-2a6cb925345c	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:59.451+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
810b4a97-f04c-463e-af1b-657586bab68b	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:13:00.33+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a6271c50-0741-438a-9296-1d44a868eaf5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:43.544+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
dfb4617d-ea5a-4391-beab-f60d0aee2bcc	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:43.607+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
b80e81da-6b70-4ca7-984e-028692a41ebe	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:44.181+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
54e4dc0a-7a77-438f-95d4-926542d6282d	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:44.809+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
21adcda8-5183-42a4-a3aa-f2588ea93e7e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:45.847+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3ec41179-5c7e-40e9-bf0c-a5524dd84f4e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:45.964+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
152f9a16-7ad4-4461-b0ac-f15f36b49a4e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:48.409+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
ec9c456b-3d81-4b3d-aa52-b7538c1a5c31	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:49.522+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
566b78a0-c810-4c3a-85ba-0151c148c438	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:50.185+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
cffae34c-9df4-47ca-9c7d-c27d9867cf4b	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:50.744+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
46b16220-993c-45c4-8141-119790c2d40c	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:51.214+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3b4ccbdc-3684-4946-b1f0-088c02e2713b	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:51.971+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
26cac4b3-27fc-4af6-abfb-155602cc1043	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:53.146+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c24e2b40-c970-49aa-9b79-494178512eb0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:53.548+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9fa7d954-f8e8-48ad-9a90-49377e0d9f61	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:54.954+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9513c5e7-3dae-4be0-ab49-8f00d192f30a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:55.645+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
cd6516f8-7a8c-4b17-b666-7c75480390b7	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:56.789+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
998c6385-078d-458a-adb2-0cedc9c7506a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:57.117+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
8a498e69-f350-44ce-a5cf-65560e1f45e6	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:57.998+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d845ddd3-5a57-42a7-bccf-b7e5ff5a1f65	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:58.108+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
4d9301ce-ac72-4088-bad1-ff0a7ffabb93	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:58.603+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
6724594f-63ee-482e-a01a-d0cc435b0de9	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:59.816+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3746421b-04b3-4a02-a1cf-0928d0bddba9	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:13:08.622+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
0383b9bc-007d-4b4d-9518-ba6949471581	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:44.356+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3bd6a1fe-654d-4ab5-8385-3c2ed2e4dc68	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:46.755+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
500eea31-9283-4f61-b86b-8b81f6114819	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:47.68+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
cb7530e8-2ba4-4384-8dc4-300ad95b7c53	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:48.884+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a359368b-a3b6-4030-acd8-608c5733133d	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:49.141+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
938947ad-6e75-4902-9707-47faaf908a9a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:50.588+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9499a08a-95f1-450a-97db-cc60e5d96cc7	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:51.452+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
b073d83b-7e22-4296-93c3-5c094d81c3ce	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:53.03+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
bd6f2b8b-2e6a-47d2-b7f4-63ba840cd969	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:55.1+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f110abd4-1db6-450c-9409-96a312217b8c	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:55.663+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
98601760-a096-4255-aa51-4882f258b4c0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:56.186+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f9c9f0ed-7236-49d0-bf36-491243ceb9f5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:12:57.421+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
4e0f4216-0cec-43f0-91c2-5bd90f1adf72	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:40.826+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a2ce8213-969d-4e60-8fd1-e2061bbe6da5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:41.324+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
90b38ef9-911c-4a5d-82f2-9bc340b2e03e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:41.431+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
90268b8e-50f0-4146-865d-7164ed0f1574	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:41.42+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
bdafc1f4-dcb6-4ddb-bf31-e1974b13743b	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:41.494+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
28f205d0-2ed2-4df5-b2b7-54184eb8f027	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:41.638+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
006e68d1-ae9f-4bf7-8761-c601193cc4dc	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:42.701+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
65adbea5-dbd1-4042-826b-11c0b2c3b96a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:43.172+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
2e919f1b-dad0-44dc-b1e5-87dee6a7192c	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:43.244+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3c048a06-7f0e-4999-9861-57b0dfd5e76d	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:43.292+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
7bc305c3-2cad-4e3e-ac4f-179d6a47807c	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:43.341+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d0209d7d-137a-4fe5-9630-d94089c6c26f	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:43.48+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
77c4664a-4e9c-4120-a5ea-0b8269de06c6	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:44.506+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f9c22414-4096-4591-b32d-c4c850a89da8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:45.091+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
03577226-d00c-4cee-be5c-03be92ab5ef1	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:45.124+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d5c1b255-02b8-44fd-8da0-9756f6116264	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:45.178+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
5e9cb2b7-3b7b-4a8a-8ba3-69db19ac0844	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:45.202+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
924860c8-f0d1-4916-b7fe-c657aea150c4	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:45.324+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
aae25ecd-72f2-4934-847a-5029f48143d8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:46.43+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
56158a33-2b00-4ac8-b592-5738bb7bc21e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:46.965+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
91bc2370-bf11-44a4-be82-6703d0605a86	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:47+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
b0a4e101-23bd-4075-8694-c42f4c76271d	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:56.909+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
71ce2a4d-906a-4f27-b7a8-766e7f5c302f	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:57.293+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c73e0615-cd15-41f1-9c72-4d8beb5b4e86	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:57.297+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a7c8b99a-2e38-429e-b628-ea5869cab430	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:57.451+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9a853e8f-6d0b-473e-87ba-e1f4f68e14b7	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:57.498+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
2001b59c-3ddf-43b2-b5af-69bc14538e9e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:59.217+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
1e2fd05b-8ad6-4b8b-a6fd-b88c9865ee53	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:22:01.13+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9aa222ee-ba95-41ab-8ad6-d4a638c2ac90	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:22:01.278+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a8d153d1-a216-42c8-9f2c-d2d6bccd7a5b	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:57.643+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
ffe5d55a-aef3-4993-811e-b557e1e39755	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:59.079+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
1a030f29-53e6-4359-8a09-9e4a0209288c	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:22:00.874+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f6317834-50d9-498c-bfe8-d5333c47e4c3	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:58.674+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
965cc3e6-0325-4304-bb3e-8df493839f92	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:59.437+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
015f6351-4171-4ef4-8d49-e8e6e657c651	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:22:01.191+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3b253d57-efb6-45a3-8f3a-9e4161955665	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:59.128+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
83c39d79-062a-4488-b1f7-01274b84c5e0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:21:59.342+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
0f96eb80-b07c-4fe8-a963-05a4ed14d1bf	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:22:02.412+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
32418e37-87be-4cef-b2b6-1d6a01efcdd6	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:22:00.499+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d3ab7286-1772-43a9-823a-4145702ddf33	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:22:00.914+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
e2cec6fe-7f7e-42c4-bca1-2393bbd73554	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:24:52.872+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
4f4bcd60-72a8-425b-ab66-4af6e7511e0a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:05.451+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
2b2f4c85-9662-4217-994d-d58d783204e8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:05.529+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
1f346dbc-c499-4e34-8086-e03c215db79a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:06.544+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
77c1e887-6601-4073-b032-e7511cf92d54	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:06.624+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
4ec0135f-f122-478b-b148-a01d56cf1a8d	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:06.721+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
40b3536a-de4f-46f3-8676-60e91360d9b8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:06.719+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
5c50b62d-a5b7-42a4-8fce-0d7a16e3f585	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:07.275+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a1186cd8-53f9-48e2-b147-7e8e45bdd104	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:07.478+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3fb4ef67-33d6-40c7-9353-5fd33c059ba3	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:08.417+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
fa321957-3dcf-40ea-b9ff-40dea29d30c5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:08.525+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
13a78906-449e-4e2d-941c-812ff1ac9105	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:08.584+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
74aa5bb2-3da6-4175-9229-36807e6a6bbf	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:08.653+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
1ff0ecf2-6b33-497c-966b-2c43a0db45ec	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:09.112+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a6a9fe27-4f00-4caf-9109-9657fb6dc0d8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:09.345+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
5088c922-cc15-4e2e-b676-adf2818d299e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:10.242+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3f467b39-fd61-4ef0-86a7-ebf95632aaac	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:10.381+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c9d4336e-499f-46db-a197-a1e811b40c56	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:53.66+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
60dcfebc-7b10-43d2-b4e7-7403e860b668	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:56.009+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
1f1f8b55-60eb-484c-a4d8-c01122b78bff	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:56.07+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
050051e8-bd7d-4c89-b052-04c894075fde	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:58.167+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f60b2a20-af2c-4ff8-9ae8-7cfcf78963dc	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:58.238+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
5a4813af-3ce3-466f-abf9-7d76b03d1f98	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:58.406+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
48896096-da80-441e-a70d-1e97856bf1b2	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:58.706+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
fa997af0-d1a1-4f15-95a0-a87b345eabb5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:59.075+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f664b19d-8489-4014-b5d5-e37b192d0494	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:25:59.878+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
25daa9a1-edb7-4f10-8c98-69d0eae4b29b	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:00.09+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
e19e2746-8b5d-4a39-9122-7cb471b16fb0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:00.518+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
97473fd0-67d2-41cc-8646-15d1c13bcca6	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:00.739+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d05b0767-a61f-4ed9-b141-9215408cdcdb	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:01.037+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d93f98ef-5127-4c99-b322-66128ef3d2ad	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:18.23+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
57512f63-3d55-4eb9-af6a-56c434e567d0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:26.884+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
e624a600-cdf8-4251-87aa-1657840a5553	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:26.891+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f4c2d03c-35a4-4a3e-bbd3-76c8ad65502a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:57.529+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f3da3999-7d42-4cfe-8d12-0cd4316e921a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:58.116+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
0d9d9615-4889-46ef-b6cb-d7f031bf1dd3	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:58.234+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
5f6129de-f8e4-473d-a2d3-56c8517d22aa	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:58.499+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
2e76d3af-6fa6-4b14-b4ca-1ff998d83e13	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:58.781+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
de27139f-f825-4f8a-bb50-6c9e7c8b1e15	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:27:00.717+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
483aea08-662e-4339-b574-be3bb12bb737	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:59.399+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
45063c88-4937-4428-bb74-ac216e9e0e71	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:26:59.918+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
529daaca-64a7-42c7-88ea-3218feca69f9	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:27:00.341+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
0277e4f6-f819-4fd6-8be6-0ed0feba8d7d	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:29:57.049+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
4ce9ef67-13f6-487a-97b8-f8ceb227d70e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:29:58.414+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
688b14ed-33f6-4d54-b332-76f1f31eb0ae	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:29:59.527+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
380c8910-b5bf-4ef9-8df8-364cc84b9716	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:29:59.596+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
4fa0ac69-5018-40f1-b0d9-70e584e1b22e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:01.39+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9c5b0082-6d24-4083-b4c1-8bfa8a01e8f0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:02.937+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c3682bc4-84cd-4566-b514-29b8242b1b45	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:04.163+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
b7b432ef-7a5b-49d8-8781-e26fbc67055a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:05.547+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
0bb28186-e9f4-4170-8b41-4fa141765ad8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:06.903+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f57f90da-3007-4428-8aaa-ef296be8b229	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:07.676+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
6cf29d6c-2f9a-4e1a-90fe-52580391f74b	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:08.727+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f5878abf-e6af-4041-a5b4-54497db37272	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:09.653+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
fee004fe-8c2f-423c-863e-4bf720e6d7b0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:30:11.649+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
999cfa23-eb31-4a9c-bc8c-4befb2c9e429	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:16.078+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
350274e7-15e0-405a-80a3-78b3ab44b664	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:16.315+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
22404a00-29e8-4158-b6b4-b7b2fee2442d	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:16.46+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a3811496-6f3c-4c11-89df-cdf5d50484d5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:16.845+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a6443d4f-2726-4391-9d48-69a06f6dccb5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:16.983+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
15498091-9a79-458b-a8cd-e09492d433dd	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:17.886+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
58e0dfa6-1b52-4420-acfd-86a214fd09ed	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:18.228+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
cb0cf503-8032-41a4-8c2e-ef1f81fb4e5e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:18.651+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
50146658-7464-4084-9e40-ac8e8d2ba9b0	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:18.793+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
8bc1c9df-4f0c-45be-9b10-b72c6b456deb	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:37:20.42+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
5f3496b3-ea15-4ad3-8489-a2ebd4576ea8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:41.983+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
05695418-9a9b-4d75-b89e-a6f0b2e11536	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:42.193+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
e3f47b92-6ef3-4c13-86f4-c0f152c4049f	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:42.368+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
956fb4f0-0d23-49c0-8b06-c5a9e3a698da	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:42.626+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
9d1ff877-b3be-4445-88d6-bf0893eccd83	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:43.055+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
22c537d0-adc8-4437-857e-894e0b103a29	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:43.833+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
6321b377-d749-4105-8322-a8787caa6451	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:44.11+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f437940f-a04a-4dfb-b700-a8375d3da6ec	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:44.547+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
17cd4420-e739-4170-b759-a6c277351f43	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:45.042+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f6046f30-2e3c-49d9-98e9-dd2c190cc0ea	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:45.157+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
6a68523f-63ea-4e1c-8f3a-4b9555a114f5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:45.66+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d412caf0-ad94-4f68-91d4-7555da1c6dcd	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:46.024+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
ffa874bc-ce4e-49e8-8257-4b5f30570ec1	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:47.631+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
180bdba8-e2c9-4a31-b56f-2b331af40cd4	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:48.041+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
afd75888-9a66-431c-a28c-65be04035d6a	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:50.834+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
27fcd9ce-9a79-4618-b443-2665c20fc075	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:46.528+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f4a3890a-cbac-4b1e-860d-74aee2707d92	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:48.927+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c8266212-000d-40d1-8823-eff5547557af	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:49.402+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
79e447d0-41be-4d28-a0de-1ab0f46a476e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:47.011+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
51c0fdc7-89c8-48da-ba2b-58f34268fff1	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:47.389+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
75c84412-7de7-49ed-83ba-e16e190e0d36	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:48.384+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
489a737a-63ef-4bfd-b9c5-e39d1189b705	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:49.793+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
0fdfba26-62b2-434e-8d63-0d53d18dd266	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:50.026+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
15827e9b-87b8-480d-abc5-455c7d6f2940	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:50.445+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
4f5f3ebb-75b0-4f20-a053-ab04a53b9c7e	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 04:38:51.295+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c2b2cccb-abf7-442f-b434-c3892651a39a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:18:57.167+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
37477f42-24df-4e3a-8b3a-fd9b393df851	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:18:57.605+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
638bd0ca-9cb1-48e9-baab-d16c1e40abc1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:18:57.732+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b7daa104-e1b9-44e5-b26f-e60da83aaf17	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:18:58.299+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9cee63a6-7935-4131-a00e-489fecfbdd70	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:18:58.468+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a23e7e93-6388-4a75-8054-d0751173476e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:18:58.684+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0342a6d8-64cc-4c51-a8e7-aa6671a122d0	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:18:59.008+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9848b0dc-66cf-4b3a-98c5-14317058061b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:00.287+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b8a2236b-9af2-48bd-9b71-ce48f90c0bd1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:00.402+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ccd33302-5ba3-427b-881b-0a2fd5ebd12a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:00.893+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c4a862c9-c89f-4114-84fc-68783a16a6fd	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:01.284+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d7daa69a-fe17-4809-a579-5b0df63bdc5b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:01.451+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5e489d74-797c-4fcc-80bb-2dd346fd9f51	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:01.484+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e855cc5e-c249-497f-83a0-b65b037b2f8f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:01.836+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ad7ee6fb-1b5b-48f3-ba07-9d0306c62f76	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:02.164+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1933f9d0-7f1f-4340-9a28-37c6047631ae	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:02.438+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
31d692d2-d639-421b-a460-fadebbb255a4	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:02.452+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b844dcdf-0e87-4c7c-9fdb-683f3a0fa6a0	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:02.64+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
69f3eef7-6234-4b5e-8f8f-eaaa96feb96e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:02.687+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
35527263-5137-4fb5-8472-38b25dc5631d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:03.505+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
18d18e1b-7c93-49ce-b99a-fead22585fae	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:03.506+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c46ce8d5-c5b0-47d5-8140-609ee97f5a97	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:04.672+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
170bed9b-08f4-4287-a6d9-7ce7b5590161	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:04.678+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
515223b2-b357-4783-83e7-32ba8ea46086	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:05.384+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5455d1ce-e109-4d38-8d9d-f7099cdc0e7d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:05.284+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6c7219e2-5097-4e54-a316-75a43211684c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:06.894+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e854242c-1f66-40eb-a3f6-9d958ac08d79	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:06.894+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1621b8df-ade5-4d50-ba41-13909a0bf807	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:07.189+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8306bd39-5586-4dcf-8627-bfdf977ad768	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:07.495+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
31b4d6ea-75e4-4df3-86c1-4cd832f50e9d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:07.594+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c47e0992-e791-4b2b-9761-4f55d9c836c0	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:07.687+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6ad50f33-95d4-46f7-8324-47e6a7e0002f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:07.783+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
341e7afb-4435-4e2c-8252-d06ad7e5c714	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.185+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
662f2add-e232-4087-b45b-157cf17f9d71	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.484+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
640d9ec6-7dd0-4467-a165-6691a24edd04	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.694+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1b934496-9aed-47a4-91d2-4fb7f51e37cd	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.982+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
eb5eb341-3112-446d-9f89-08b94355870f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:10.303+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1d718d2c-6676-4eed-9bda-ab1d7a14cf72	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:07.983+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f3916fcc-adec-4754-8aae-adb7407f69fc	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.181+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a3203136-7e95-4238-8a7a-02a1352e773c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.483+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e63e638f-7455-49c4-9902-258c3622ffe8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.486+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a42ad208-5c31-4f2d-b094-8646853d1fc2	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.493+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a12c3557-f297-4cb3-93c4-85b1b8ec97e8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.495+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1205b2ed-b6bf-4108-a903-67596f369661	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.598+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
98d1d680-7567-45f5-ab3c-6f43af32463f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.696+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9e7fcc33-ce39-47ae-91de-e42d4a77537f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.988+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2555faf8-6f80-4e0b-b399-08b99dd3d54d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:10.421+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
82ea4f36-3375-45f6-987e-848af3ac82ee	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:09.984+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5fcd8976-75e6-470c-9c46-fa170628a3bd	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:19:10.384+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0141ded1-c50d-448c-a022-48c254df8b34	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:26:29.997+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
577d056e-ac03-4a0d-abcf-d6437602d6b1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:27:12.524+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d6861449-aac1-4b94-807f-c10c37f5c4ad	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:46.048+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
07ad67b6-cc0a-4261-9813-c2be06e31a95	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:46.89+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
421a12a4-b5b5-46a0-94e5-121f110146c6	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:47.387+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d361f091-3471-4c23-98ca-69c34acecf82	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:48.01+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9c3fed73-3a7e-4b61-8957-edef109094f3	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:48.327+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
117effc2-2347-4f9a-bed1-fd8891182cb1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:49.338+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3277cb87-28ed-4949-a26d-c14e2b201954	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:49.354+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
52081bd1-3164-4c1b-be86-932a7970b63d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:50.125+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
eb77d832-f9f6-4565-90a1-8d56d4e40e42	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:50.181+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9ff5d28d-ef3e-40d3-b52a-51ad08a5f6bd	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:51.621+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fe295c81-3fb4-4c7e-8b0b-ca4a2e190b74	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:51.638+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a13502c8-da75-4db1-85a7-d37d8e1f2717	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:52.249+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3b4acd41-28a4-422b-9b9f-2d6327391dd1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:52.701+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6a949ded-6430-479a-8a87-89777f7ed84e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:52.795+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a9cf91b8-4e58-4d22-8963-6cfedeca7faa	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:52.89+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c317cc09-37c7-476a-9f1e-a8bd755b569a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:53.435+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
05e33147-b5d1-460b-abd0-7ae532d20a02	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:53.48+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6a15e80b-0692-4d1d-9eda-db9e82ae512b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:54.053+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ea4bcb69-0e94-45ae-8653-2a205d89a82c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:54.517+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5d0fa5b0-485d-4a90-84e5-58220095ca19	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:54.596+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
55131cce-7249-475b-94ac-d0b1ffc73e1c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:54.781+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c298bece-8c89-41db-92b7-eb1af8e81794	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:55.265+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d327f16b-4363-4aa8-b604-80b475823d9b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:55.297+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f8ff4bfc-fd7d-4846-8725-91a1e6f9f8b7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:55.892+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d32f62a4-c794-4112-b3de-c4cf5f35ed82	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:56.393+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8c89204a-4c5b-43ac-8774-d45c067e2c1a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:56.399+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
83f22e65-cc4b-45b1-a358-4e5d10ff92da	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:56.564+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ff345138-ed5a-43cc-859f-989aa787e2df	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:57.093+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ce47735a-d597-4619-bc84-2e03581a4c20	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:57.466+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8dd3932c-549d-4237-9901-a4558b08aeee	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:57.767+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
eef44089-5384-4727-a526-9984fde5808e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:58.203+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
847b2c5d-1762-46ec-9b7a-3030d6edee91	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:58.233+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e68742e2-0c4b-4c1f-8626-306ed5e2a755	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:58.493+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c03bdb9a-b4d9-429a-ab4f-c7fd419de12b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:00.024+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fe43b094-3990-4620-a1f0-1f244eba196d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:01.124+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a7e073fe-89e6-4e1d-9ecd-2c8f2f1551df	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:06.291+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d57d46ea-6fc7-40ca-8885-57f86960b073	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:07.359+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fd6debe3-0723-4632-b087-81243c3f3fe2	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:11.825+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c1b30eba-1d29-4818-9be7-804d5667a339	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:12.056+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
35a853e1-21ff-41dd-a7ba-bdf4f39f8a5b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:12.329+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0a6bf650-2342-4d52-9493-3600a2a3c5ce	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:12.826+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
acc0aef6-6505-47ed-8acb-8f03df46691b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:58.916+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
02b0ba1c-3bf0-4311-9c8d-438c55078b18	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:03.759+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d5b8c22f-4cee-4c24-85d3-a6f3c356404b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:07.849+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
855fecb5-3177-4a80-9c65-460eba3f64c2	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:08.697+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e77fb6e1-881a-470a-8613-b8a4e7d5de63	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:09.414+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
37e2bdbc-a75c-4252-8624-6ce2bf74015c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:10.011+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
07e53006-db52-4b3c-bfee-8958e3d5eb8f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:10.255+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e6093a48-db10-499d-ab3b-9bf7e94b3297	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:11.047+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f66b774f-fa5f-409f-a25b-af366b3b16fe	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:15.168+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
97deba63-2f31-432b-a9b9-97b45ae0d6a9	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:15.972+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
eb89a738-f69a-4051-9055-34c937db551c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:59.267+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
504d057b-7bf9-4752-a920-27dfd79d64ab	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:00.705+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
40010482-dd51-4aaa-8a42-504b0a0fa8eb	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:02.544+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
67747f55-94a0-468c-9570-7caa6ca970f3	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:05.466+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9dfb8cb0-d7d6-4aaa-9e90-9e7625549fa8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:06.624+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0627821e-509d-4c0e-ae0b-f9b1073b12be	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:06.84+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
70d8024f-81d5-446b-be55-088b96e937fa	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:13.044+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
517fbb4d-d081-4aad-8eb3-40b51259f843	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:16.496+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2731171e-a44c-41f7-9aeb-2883837fe27d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:40:59.599+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
86145427-0b23-4a3b-b8f6-67fa13064c3a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:00.051+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b3e9911a-b704-4094-8d05-e06bc294a553	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:01.391+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
457b9712-e4ca-46ae-8056-1a940fe2e533	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:03.637+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c926941c-f7ba-432c-9595-e0de36035b83	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:04.414+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
60a88275-aead-4991-95b6-672fa5e69532	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:05.007+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5b83190b-31c9-4f79-afaf-d2080c2f74d8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:13.386+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
944596cb-f467-4662-96c6-3f447b97b0e8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:13.591+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
47ce305d-a8bf-4ee5-9ba5-9afefb179597	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:15.73+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
26254aed-c7da-4db0-86b1-732f7a2bf6ce	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:00.309+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
04187669-a1c1-4354-ac03-2939be9c90d3	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:02.991+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
89182c69-d661-4fa2-9809-4abdf723c824	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:07.587+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
db2ccb21-4b93-467b-9efd-55eb0bab0c3c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:08.16+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
41dfa351-dece-4783-818e-c30d9783c6a1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:08.424+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a91abd6b-7447-4305-9616-65726d3a5b04	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:01.85+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0e4cae73-a04e-4b21-b4fb-f3d80bfaa9ff	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:03.954+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9c629f6c-4f89-4458-9c02-09cb7221735b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:05.554+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e3a5e8e2-75be-4b43-9ad1-34762bef934c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:09.641+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
65101fce-2686-4673-9f96-54eb929df842	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:11.469+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0ce8b87c-4961-478a-87a8-9e702da1a79d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:13.884+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1df7eda1-b518-44c6-9eb1-c75e7fe453f8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:14.107+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5ab48751-2714-4457-84a6-8068c8cb5dc4	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:15.412+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c8b2cc38-4d6e-497b-a6b7-a6c28ee4cae4	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:01.867+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ef6df75e-4cdf-4a56-af32-2b17f76274a3	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:02.159+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ee0ad4a5-50a8-4a7a-b94a-cd0648c82b6a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:03.224+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
22fd867e-093d-460c-945a-1fbe1fbcbc8d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:04.777+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5fbd5695-7e8f-415e-9b7b-e23279ff5afa	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:05.783+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4ca2e47a-a1d9-4244-b114-235b33e6b831	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:09.151+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ad5066b3-1a10-4a1b-88af-617143fa6cf6	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:10.483+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7e7c0f24-293f-4df6-9d6c-aa18bf71ac88	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:11.229+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9cf58eb5-6165-49cd-a958-4eb6301e8a67	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:14.64+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fa0cf00d-c054-4950-990a-3b351f9eeb43	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:41:14.868+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
03affa8a-b13a-49e8-9936-569ca92e26c4	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:31.106+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
841147d9-99cc-4e31-b35a-24d646654444	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:31.203+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2ed19c7f-05f8-400e-954f-694d24e5d61c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:31.271+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
00ac5a93-3e68-4017-b99c-1f5bf7fb62ca	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:31.42+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
235f1716-8f59-4b3a-a55d-894b7b27d898	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:31.432+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2eebf597-7aeb-4d9f-9a8c-9cce5f634511	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:31.465+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
651c3f18-193b-4f66-a966-f47ed2ca3a36	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:33.026+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
71e73a3d-7138-4369-a1e5-a4915ac5e7c1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:33.041+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
105e4cb3-db4b-4ef1-91e4-62dbad2a3461	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:33.322+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ca6bd9e8-e983-4d6d-a60f-5fb108a48d7d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:33.31+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5f90801c-40d3-40a7-a23a-0a810b8be2e3	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:33.354+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e5125239-90bb-4fed-91b3-5c38f42ed3d4	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:33.363+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d750e97b-4008-47ab-84a8-205540914621	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:34.89+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3c340bdb-a6e5-4c39-8e68-8d8ef3150e22	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:34.896+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a27c8708-8051-4163-86fc-7adefd6f6011	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:35.161+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
34db57d6-c3d4-4c28-820b-ea9bd052df9b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:35.205+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d3f136fc-cc62-4c7e-9d64-8faf66bfc9b2	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:35.23+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f8ecc34f-2998-481d-b4ae-3461e33735f7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:35.252+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d9bd8227-b6b9-4b96-8558-0ac71616d795	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:36.703+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
306394ea-eb5b-4188-b382-7b2e7660bc18	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:36.709+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3f7ce875-ca9c-49fd-8a3c-22ba2f8dca85	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:37.041+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
897259cd-25b7-437c-961b-9be3e2266689	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:37.051+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cb1ca1d9-e1f2-43f3-ab11-b70c945c0b18	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:37.152+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8547639b-899d-43c6-be39-879d7bca13ad	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:37.246+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
239eb41c-3a1c-425f-996f-101af3e06aca	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:38.538+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
23030034-59b8-4f80-8135-f57c0bd9a66a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:38.593+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ef7ccb77-f676-4ff8-bce8-fcd83b87997e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:46.383+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a7a2d3e9-dc47-47a5-8f62-1035124a12d1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:54.155+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
74ad1cee-0ae3-45b1-a99d-4b3e0bc2d4f7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:55.404+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0941d13a-8836-4113-a530-28a81659923c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:59.353+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f0fd1807-4b92-45d4-93dc-17a3bae52fd7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:02.854+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ccf11a6c-0a3e-4ffe-8813-64c06b8d0e5d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:03.134+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a02ea91e-f7b2-4304-a7a1-bcf0a46775f5	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:38.845+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7782831d-7c99-464d-9d14-086c91e2ce9c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:40.482+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
04cd9d38-8b94-4a78-a228-b74719534b6c	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:42.466+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1d3e7b1b-dba6-4c89-9c62-98c96ad35f89	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:44.345+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
67cf7032-c839-4075-8edc-63c3705af625	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:49.945+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3b6d24ae-aeeb-4f21-b4ee-ae5cd4a90012	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:52.197+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ab7d7999-859f-41c6-be4a-d1427114e88b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:53.713+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b6637465-e664-43a9-a8af-23d6948e50ac	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:54.013+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bdbe50fd-0b68-4b3c-be57-d74e734754be	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:55.828+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5961ca9a-89ef-4f2f-a4f3-c767d1155e9d	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:57.399+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b35bdb14-f0e4-4b0c-a41a-544c8e8c9562	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:57.745+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
faa45e54-da61-4923-8c7f-077d7ef7facf	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:59.242+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
01f3625c-6404-44ed-889c-0c082b0743bf	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:01.163+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
388970b3-5736-4f96-a9f7-e048fc7c4080	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:03.015+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
040bf5c4-34ac-4449-b151-255a19b28174	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:04.906+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e9974e51-59d6-4729-9512-99fc10e66145	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:06.728+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
13bfbf24-3b7c-4a6f-ac56-2329dd1ad011	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:38.87+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
98d6da95-9ede-4e8a-8dc8-f755e7c1a249	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:40.623+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2b639d99-931c-43a1-a2fb-2f69a7b6b8d0	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:40.897+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e1804884-f199-40a0-a7a3-f2d91ffb58e6	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:46.199+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f6563d2c-6789-471a-9055-2885e61723f7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:46.722+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c36d1f7c-1665-48f5-8ca1-b51d2c3ab865	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:47.749+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c82b2b2c-81e4-4fa1-a60d-2d1554c1d8b1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:48.202+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
54a083b8-2438-430d-90f5-936a1bf1b12b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:48.535+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5f66fb3d-e339-41e2-805f-d2534f2fa1f0	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:49.98+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
baa05f0e-6e87-4ad1-bee5-3042cd383ece	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:52.012+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
05ff0554-2ed2-4af9-944a-a66a9bcd2721	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:52.218+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2022fe30-6e56-43ac-81d0-0a4d7fd93c9f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:53.595+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
18f43943-512c-4656-ae66-ba16a41154f2	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:53.835+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
99ab40b5-3a3d-4090-b608-c91c4b3f88f4	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:59.523+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3308aa56-627f-41e2-8a03-f50a979c99a7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:01.066+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
67649d19-9aff-48c9-8a9f-128e08cb1a6e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:04.746+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
de94e504-3816-4e05-a243-c22dcaf778df	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:05.114+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
38ded5e4-9e99-4dae-b6e1-de75728e9abc	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:06.639+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f85dc5ee-abb0-4523-bec8-28298ad6f785	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:39.02+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ab43bc8c-84d9-4b9b-ad6e-d25c66536d75	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:40.368+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c1fbe38d-2c9b-4bfa-a16e-670e8603d971	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:44.234+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
148c78db-2b9f-4660-955f-dfe4460fa862	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:44.521+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b6351131-ef29-4d78-83ce-308da5e87033	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:48.259+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2c30ed69-d508-4392-92ae-d550691b0d5e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:55.711+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
48ccb700-c911-4b34-a15e-c5f897fd9eea	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:02.912+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
38a5f0f1-f378-40dd-91d9-97618a4ad4f8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:03.296+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2c1e2d6e-ec3b-4eb5-98aa-dad48c765ec2	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:04.787+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
542557f7-027c-479c-bde8-05d5371619ed	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:39.125+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e8e067d6-29a5-4bdb-86c7-17b76af9221e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:40.993+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b2828ea2-ca24-44a5-9838-697cff8580f5	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:42.374+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c146f0fd-c9f2-4e9e-bf70-bfdcfe69cc1e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:44.815+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
39c89f1c-393d-4d58-9f0a-6645e7f0584f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:45.92+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2424aaa6-f6b4-4b7a-bd9a-9be51f67c91e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:48.561+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
485ddbed-6856-46b2-965d-2e5e438054bb	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:50.321+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1e29bb8b-b3a5-4297-a233-4f751562e694	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:51.457+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0947d6bf-6fd9-413e-965f-70733b39d9db	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:57.695+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6c453dd8-6ec2-4785-bf79-935de80373e7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:59.199+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c0af1b94-f99c-4d58-9d09-3ad41a7b1f83	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:59.548+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bbabafb5-b03b-4bf5-89f6-d7b1df86a34a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:01.049+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4974b36f-cdc0-478d-95ec-42795db0347e	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:01.426+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e0342ca0-16c0-4ce7-9558-d679416798ed	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:04.819+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d1a60a77-70b4-439c-9a7e-6f6e307021ea	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:06.673+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
345fdc08-745c-41a9-bcc0-28bde2500cf6	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:40.752+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f9cf13bc-8ab6-4d42-8a79-bd75885aaac7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:42.232+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
00ab8738-45e8-434d-9cd2-c1d4261d24b0	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:42.815+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
184c3506-b3f9-4911-9cab-8375d533ae74	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:44.033+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
caeb5cc2-f635-4e3f-bf06-71fa8494f8e8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:46.257+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d3d9d1b8-ad96-48ea-ad36-08d25340cc6a	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:46.588+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d63c3604-6b2e-4be7-873a-7d8796dc0145	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:48.081+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
12ec6147-1210-4998-ae6f-a27f766c4635	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:49.618+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c3915e0f-b896-49d6-87e0-824eca06517b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:50.097+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b395c1fe-9beb-41d0-99e0-da576ce971f6	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:51.838+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fefd4a68-d5d9-4c8f-a58b-e8d3a2afe229	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:55.564+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
057aa626-484e-44f1-b198-8089a8b8d5d8	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:55.919+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b69b79e7-b5a6-43a9-99be-7b396693c689	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:57.193+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6df4a532-6248-4169-9ec4-f576fe3359e9	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:57.413+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
10a38ffd-32ca-4896-9c67-8962a2a3c384	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:59.053+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bb538839-f126-4bf9-bfc0-6e5880987928	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:04.679+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2265503d-2a90-4ed7-87ca-8a5fe6fef7ab	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:06.477+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4c2e66c1-9647-4423-8bb9-f626ffac7945	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:42.673+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4f2e3274-2cc9-44dc-bc63-c7600ac5a172	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:42.907+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3928d79b-84c8-4a03-872b-333f17118bd1	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:44.695+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bdf956de-229c-47da-9a33-2fa0e2b702b7	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:50.387+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b6b45415-d199-4da8-97b3-49a5e562f1c3	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:51.833+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5d5258cd-7a9a-4721-8235-7d00273062de	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:53.77+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
deeea30f-9761-4b38-9841-a43f2cc2d529	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:55.606+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2b9c4e04-9d4f-4307-9960-9b302d29b97f	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:42:57.526+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
92d540f8-3944-4dfd-9039-b744f6d94912	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:00.883+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2cf158de-798e-4b98-b7f9-308a68cd01f6	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:01.359+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a41a14e9-c7ec-40d6-b0e2-685389217140	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:02.852+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8cbf695c-4f2b-41af-88d3-b7ddb2af18ca	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-11 06:43:06.535+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6c0c30b9-3a49-4123-b1f6-c244270d2783	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:46.976+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a3daff1c-a067-4a8f-be08-446c8f46b9d7	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:47.62+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
55f1ad13-c678-4d3d-85e2-fda9743a13f5	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:47.788+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
becef7ed-5dce-43a4-b047-a29ba5f20792	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:47.909+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c3f5eda2-c2b9-41a3-b073-43b0c8348f34	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:48.207+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
6052b020-0347-4a5c-b658-2239140fe8d8	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:48.822+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d00b6342-65e3-41f4-97f1-726cd9e30335	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:49.474+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
bdc099b0-2335-4a30-8888-ded12c4c4cb3	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:49.587+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
cb95d111-3474-4a17-842e-3982984f26db	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:50.051+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
17465efd-52c0-455f-82fc-b4ff695eed54	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:50.265+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
cbda64ae-57d6-430a-8558-284a63bfef29	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:50.753+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3c158efe-711f-47a5-8fbb-2fd5548e0edc	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:51.289+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
417624ad-ba14-4146-8ed3-de195bb28415	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:51.689+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
d627da3f-1b36-4efb-ac40-1703eb0427bb	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:51.991+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
3256b6dd-d14a-4ca9-9c91-50580371b228	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:52.447+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
1c06fe55-6d13-4985-8fed-13c898c6d85b	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:52.609+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a8fabe74-ab9d-4307-9bb7-3e9d113b64b6	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:53.103+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
c8de4484-3094-4313-92c5-131e382a2153	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:53.691+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
af0dc8dc-3587-491d-91dc-3668071d612c	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:54.098+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
ae702fb7-1774-4fe7-aa4a-98c1eb227dea	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-11 08:16:54.353+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
7d0c54da-8c05-4f71-8f6c-fcadeb399176	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	\N	2025-12-11 08:16:54.621+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
13b12948-2a97-492b-a766-6c3928a4ea4f	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-12 11:51:42.741+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
a734b09d-681b-4ba9-96b6-246d78afead9	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-12 11:51:42.934+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
f98b6a0f-485b-4ec7-b8b3-9e7a3c0ea287	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-12 11:51:43.118+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
84a5fc4c-bf29-4ff8-9c87-bc4ffe63d3ef	harith	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-12 11:51:43.125+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	782c37df-f571-4390-bd69-fefdb0e13cf5
fa8c2ff5-d390-44ec-91c9-b33541bc7183	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-14 12:23:10.018+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ddc30792-e908-4ba3-a85f-905b6b39db86	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-14 12:23:10.835+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6d820efe-47e7-43c9-9def-9958dccea01b	Jarardh  C	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	::1	2025-12-14 12:23:11.577+00	f1910903-120b-4789-baea-38a17e5c8e39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bf5dd617-3042-47e9-84b9-e315e6468a44	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:16.518+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8e8d7b08-9062-45a8-b131-a59ed6fc769a	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:16.598+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
30780c69-2d20-4eb4-a63f-509b8881d6ab	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:16.569+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f25c54a1-3324-4d41-ad9e-e1e158334c11	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:17.16+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3f9d2983-fff1-4b31-92b5-7fc7f7b227bf	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:17.944+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cdd27965-a2d0-432f-b6f6-7dce3bd6e412	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:18.404+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
dae44ff8-2f08-4d8e-bab7-d2b25fd61eb7	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:18.628+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2673826b-deb0-4e7e-84a8-4dbfc3ac851b	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:19.07+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6c9975bf-be39-4b54-bf42-95586e928658	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:19.63+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a4d430ec-e2f1-4f66-8cf0-3c7645c6ce61	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:19.867+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8895b0d5-4c3d-454d-90cf-c0099eae5547	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:20.446+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
520c121e-202e-4b87-84ce-2ae2754f1dc8	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:21.055+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f2281523-3fcd-451e-a369-2467461a8700	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:21.399+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c13881f8-8eb2-4979-af7b-7ce8f1961d86	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:21.742+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
56674065-90b1-477f-8451-1480f6eb770b	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:22.289+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6fa6e923-a3ab-4c0f-9705-adc1f407f6fc	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:22.463+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9c2e72a6-5aa7-47fd-955a-eb286d8fe129	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:23.022+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
09d124c6-bc10-41e7-bcfb-79c585987a4a	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:23.75+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
07b7a188-ea40-4897-bb11-ee864a2b113c	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:24.283+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
75a49d31-e5ab-439d-9c35-6293202b5cb9	Unknown User	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:14:24.374+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e34fcac0-f48a-4381-808e-93db6a60194e	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:15.693+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2b2317ec-47a0-4d14-bed1-c227f67c3531	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:16.245+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c4b3193a-9418-4832-b9b9-b5f9d41171a5	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:16.318+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
077d8e60-b2d8-4dc0-a9f5-7797835d6041	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:16.326+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
85cff186-5366-47c7-b538-f0f6f64650b3	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:16.428+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
11aac4c9-ced3-48bd-a51b-d85462edb681	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:16.898+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fed6c97c-9187-433b-9d35-0b5d93602aef	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:17.981+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8b2a4048-1a6d-479c-aee3-a4ddd2d8ce90	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:18.08+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f9be9a50-2ef8-4e60-954b-a38f64326f12	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:18.305+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
89c7a451-8fe1-4a9d-9c03-8657c9710f70	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:18.482+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
357baf58-cbd9-4ed6-9e66-945c6544f133	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:18.847+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b1d522cd-8505-4dce-9dfe-edd7ad81ce03	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:19.419+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7fcfa867-defc-42ac-b4e2-772abea6ddd8	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:19.82+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9584cf7c-a9e4-4f6f-a61b-df3dd5c8f211	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:20.225+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3909b719-096e-47db-9472-e82c24ca4bd0	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:21.503+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6a8faa7c-00ca-4a89-97af-e5e69f329a49	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:22.109+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7a7e6837-95b5-4b5c-8470-33912a5768af	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:22.571+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8fcf4512-1fcb-4725-b0ac-8786f57f13ec	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:23.151+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c56130f0-03db-4b83-85c6-4cca9964dfd6	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:23.895+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5b8611dd-7298-4d97-afbf-5676c345e1f0	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:24.096+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
372c85f1-18fe-4724-8894-1fed76dfbf03	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:24.895+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
517557e3-4002-48a2-aa73-d366567beb88	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:25.415+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
65f1c93a-7d67-41b5-b3f9-55e3f5e93ad6	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:25.691+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a482e4dd-a88f-4e01-af7b-f592bb10f734	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:26.647+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b081ec88-e2f3-4816-978a-6a251c54f396	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:27.482+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4d0bdffd-406e-442a-9a8a-951138e9b128	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:27.846+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
99dceee7-2faf-469c-a6ac-0eed3ca42388	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:28.17+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ec90468c-0ff0-4258-9738-f2c684a08da9	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:28.503+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fadef27f-b55f-4aa5-ba46-29081fd3dc86	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:28.997+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
92ba5e44-218b-42db-863f-71575c2bf554	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:29.644+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b0ce5c2e-3847-4710-93e2-608497851fe9	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:29.928+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6b5b74c9-d3a7-4dac-8958-f13e34a76ba3	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:30.544+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a108f3aa-1614-4420-bb9e-c0edcf748370	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:30.791+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b64a739e-7c5e-4000-93e6-df02e0bccced	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:31.05+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0bc29906-a48e-4b53-8249-b26efe4b90cb	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:31.707+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
000b6b1a-57aa-4dbf-8adb-4a4cd2350204	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:20.451+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
88948a52-56a7-439f-80c1-4cf420769d8d	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:20.671+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
84214705-9d46-4623-846d-9ba8b5101f8f	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:21.756+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7cb06ac7-a4f1-4192-b937-c11e221ac38e	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:22.002+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2bfebf9a-7dbf-43a8-9808-3ba78266527d	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:23.674+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2e2b6a5e-43c3-4094-86c8-b1345bb7ceb1	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:24.35+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
56add5c3-bd12-4d8a-bd19-52f9867bb726	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:26.026+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7c0a7a8b-5dbb-43c3-91fc-a1380033a1bc	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:26.241+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
60b5dcec-af79-435d-ba9b-550b46f66e6d	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:27.134+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
93cad720-2ec4-41bd-9bc4-ab1df830242c	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:29.276+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
dbc3c528-1411-49fe-8e2a-e29a651c7f23	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:31.554+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
aae142aa-0545-49b2-b973-efa7df0e1e2a	Jarardh  C	Adult	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-15 09:18:32.366+00	524e780a-0111-4ddd-8c6e-7d500eda06ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b59acc07-bae6-4ef4-98a7-280610386218	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:45.106+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
36e86049-896c-4001-8840-e2dce6632811	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:45.678+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
b9033c89-d354-432a-9ab3-7695be3691dd	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:47.332+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
448ac8e4-d2e5-4d50-bba2-6069ecde3a14	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:47.333+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
b1d45bbc-14bf-47b7-a6e7-5fc1eb689e59	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:47.634+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
37975c97-3e74-454a-b6c6-e435ff1641d0	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:47.639+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
e3fee64a-f441-4568-bce9-f246c09644be	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:48.039+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
9be37bc9-4343-430f-80dd-23d1dced8fe3	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:49.138+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
96f324b9-ac84-4aa4-9859-93854203b968	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:49.43+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
27682923-db60-4388-8743-0e25f87517fa	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:49.931+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
0f01eaf3-d6a8-4c6c-9ecb-ee82c7d0e882	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:50.028+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
722093ed-8e00-42f9-b8ef-03f4c34fee55	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:50.333+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
2f192d08-5a72-43c7-89bc-cda394e3fdd5	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:50.933+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
93e04688-2a07-430b-8029-a403a7c29d63	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:51.134+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
9290cf6a-5a9e-471f-a044-4a744a080749	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:51.229+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
eab91f87-8d3f-495a-9ddc-8744d29aa400	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:51.537+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
4877a55a-98c9-4d28-80ef-63aef7857c18	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:51.538+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
22cf5422-c4bc-42b2-95ed-3b6c804fb686	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:52.129+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
dd70424c-ee7f-404a-9e57-106e1bf919c1	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:52.131+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
835b0428-e1a2-42ed-ac7a-efca875b1827	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:52.233+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
68f6a1a4-ec6c-40e5-bc87-7e8c38fe98df	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:52.332+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
4b8909db-6a04-4c81-92ef-15df2abccfa7	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:52.731+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
227debb8-7841-4cf5-9821-6bbffd50fe1a	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:52.735+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
2c97e5f6-9bae-4e30-82ba-535325649ef3	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:52.738+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
d908cfbd-c258-400d-ad87-89e3cf9a739c	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:53.334+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
4f7f711e-506b-491e-b90e-37f444ef131b	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:53.639+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
73c70aaf-eeb5-454b-8276-37d65e57e242	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:53.933+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
5f66dbf2-d037-42dc-8d15-4409d74e9f6b	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:53.34+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
77e597b3-1b70-4be8-8c3c-22aa7746aaa8	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.329+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
fd1608f5-bac0-4168-9b3d-98c703286541	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:53.427+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
7ace6d1b-657c-4cc1-9b5c-c15b1f51df0f	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.626+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
5cfb799a-135b-480f-95d0-934e495637cc	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:53.531+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
7f2722b7-2303-4367-ac6c-f87cbe11a47a	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.332+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
6386a5f1-085c-4fb7-bbb8-0d8b3c278c28	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.032+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
d1bc6a1b-f0d8-498a-a957-d3fcbe0c290b	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.334+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
9c6c7c3d-fb98-42bf-8ee7-c12b99aba4a5	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.044+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
3273a0a7-8432-4acf-b0eb-32228d23ac07	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.234+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
196cb062-62eb-419b-b6cb-d17fc81a11be	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.731+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
807a6272-a60d-409c-b135-4af959d599fb	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.831+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
e10739f2-dbe1-4f03-ba43-bfc732df4bfe	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.837+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
40f6114c-ff37-4d62-bdf9-0b4527b6268a	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:54.838+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
98ec9631-1b5e-42ed-ae75-bd6feeb09234	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:55.03+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
f003c0a1-bff1-4a50-a61a-a34168608c6d	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:55.434+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
8e276248-51ad-4642-bcd3-f2a46f7357a4	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:55.529+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
5d4d8090-1220-4308-9b4f-a8c7e943d4e6	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:55.624+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
9eadd2f9-1343-4560-9f77-2f2def9fedce	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:56.231+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
58068af4-478b-4d78-b80e-66985ea3cdfb	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:56.424+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
fa32d852-1e4f-4b26-b662-001c7236b1f8	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:57.048+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
79fd127f-0da0-4674-9e1e-b49c455fe311	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:57.429+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
d80c4c58-c418-441e-a3e6-4dc35416d062	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:58.252+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
06048241-aab1-4f1c-84c9-1ac5234be881	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:58.375+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
2df19288-5bb9-45ca-89ad-8287aff5f095	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:58.464+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
68602435-6621-4d61-8167-83f4756b70f5	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:58.784+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
1d04706c-f8ee-4bce-bc44-30f14248c666	Amal  Jo	Test 	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 04:26:59.608+00	f1910903-120b-4789-baea-38a17e5c8e39	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5
c72e93e6-5c19-4624-b5b4-42158b6913db	Jarardh  C	E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 09:50:22.415+00	3f75a734-c9a6-4934-96cd-d7a04a3d202d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ba3d9211-412e-442e-8762-7ff1ed4bbaed	Jarardh  C	E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 09:50:25.424+00	3f75a734-c9a6-4934-96cd-d7a04a3d202d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
49ed4187-1cf9-46e7-96da-3041352c257b	Jarardh  C	E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 09:50:26.872+00	3f75a734-c9a6-4934-96cd-d7a04a3d202d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a0241f02-d7b4-440d-a898-9b2f6429c919	Jarardh  C	E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 11:39:01.478+00	3f75a734-c9a6-4934-96cd-d7a04a3d202d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0490b7bf-bf0d-4fd2-ae1b-0c2668fef9bc	Jarardh  C	E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-16 11:39:29.068+00	3f75a734-c9a6-4934-96cd-d7a04a3d202d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6d54f8f1-16c1-46e8-b77a-7a5f06f7f1e5	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:01.992+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
94985b31-220f-477f-ac9c-bac9fbba783b	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:03.378+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c10b0d37-977c-4719-89ad-892832dca169	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:04.766+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a97120cb-13d6-44cc-845c-69768ada4663	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:04.95+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6500e905-2641-42dd-b5bb-0677355ae784	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:30.617+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2922eb2e-b522-44b8-8328-2316153b9176	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:30.923+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7d484b74-0fe3-4260-aaaf-1e52e9562fc5	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:31.15+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7f15ea06-7833-4625-b9f4-81fd213dae9a	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:31.255+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8f14e5bf-230d-45d7-9b41-ba8aacf0f829	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:26:31.366+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ec19b759-3730-4fc2-a45f-b73115be72e6	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:27:25.321+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
dc6c5636-46ad-4c14-bb81-8409798ea6ba	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:27:25.434+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3467d209-f08e-4fe9-8380-9eb4e4b64da3	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:27:25.734+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b4b86b80-228f-42c2-85ec-cab0335bd605	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:36:57.403+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2f94da20-d1ce-416b-86c8-d46f7f116f20	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:36:57.462+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
aa12296c-2630-421b-94f5-181cfae082c5	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:36:57.739+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
eea2c77f-4d6e-401b-a0bd-97f8d5c21f10	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:36:58.74+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1f6239ca-c549-4a93-a2ab-6271cc32cc74	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:36:58.937+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
34e9f13f-c099-4fda-a21d-8f28de2a136e	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:36:59.242+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ddc260dd-156b-4a71-83ea-b90b6a4bed74	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:36:59.549+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0eef7666-86ef-48fe-bb60-55dd9520df75	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:37:00.347+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1881008b-fbb8-4f67-8626-366556e0d87a	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:37:00.562+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
22525270-4010-4acf-8c65-60feb025020b	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:37:03.071+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d9af1b39-d52d-4ee8-b24a-8e15b8f71fb4	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:37:03.651+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b131ebcd-3d10-494e-ba48-5ff66e6b1d4d	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:37:04.31+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
51bea657-86fb-4b94-be95-92d24fbac534	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:37:05.402+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a4aff3f7-3f1e-4cd2-ad37-7a05d6ef7e84	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:37:05.799+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a28341d5-f084-443f-bc57-eef0ae458146	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-18 09:37:06.636+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1bba263d-3b61-442c-bbc3-2e6db2e4d7ea	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-20 03:22:19.826+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
240f2c17-a10f-41ca-8000-02033c7d4677	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-20 03:22:20.314+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ef613e04-0f79-4220-a48d-5cc6e7a68c2c	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-20 03:22:21.093+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
927a6d7c-1bb6-44de-b853-4280becbf235	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-20 03:22:21.773+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
149e5a17-532b-492d-a31d-09bdd120ef9e	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 05:36:35.553+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
15affe46-b35e-45fd-9a67-409513824ad6	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 05:36:36.309+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
77ec5bd1-2478-4423-9a00-1c92ebd75845	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 05:36:37.145+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a2367870-020c-456c-9203-a78f4a1d44dc	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 05:36:37.855+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8123da44-1c0d-499f-bcb4-1f387bb60f09	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 05:36:39.399+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0f22e70f-8495-4936-8070-3e21aa3f1137	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:29:40.813+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4eacea98-4b55-436e-be25-0ef8a4a119a1	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:29:40.976+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
421e8178-8e4b-4883-a037-151fa8869f02	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:41:17.432+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cf5f78bb-19f6-4b3b-a6a8-07e743873180	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:41:18.014+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ca6f9d98-5eff-4177-b7a8-3f709bd7b31c	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:41:18.73+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7b2ed7a6-9679-4553-a640-9028d30789b0	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:41:18.868+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e8b7f23c-e637-4e25-b5dc-4f3f6f02c2b4	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:41:19.318+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3026db40-86aa-493d-80bc-deba9651a032	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:58:09.648+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e160eb68-a38a-42e2-9fdb-139d78a913de	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:58:11.844+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ba7d5bd8-d86b-45fb-a335-4cdaaaff4bb8	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:58:50.324+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
719a60b8-9c88-43aa-af47-4430e873592f	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:59:29.517+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5b9f52ce-24a4-4c2f-8f83-59c397c0d51e	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 08:59:49.432+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f3a3fa29-8bc6-4ded-a60d-72db375d54a6	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:00:09.026+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e3e61c79-a245-40e3-ac8d-98e9a2dc3435	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:05:12.262+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3a7d9c0d-32c8-4808-9550-60b9d1e71944	Jarardh  C	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:05:13.026+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
197f539b-2402-4edd-a3b9-628062bdec1a	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:07:58.967+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5e37fa53-bb1f-4111-94dc-4b048a138419	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:07:59.879+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5a5e1a0f-7a55-4f35-b1f0-96d3ac906c52	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:08:14.397+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d92ac474-a385-4a2f-bab6-7da5c4abda8d	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:08:14.727+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
653e877d-ca00-453b-b9c0-eccdf8ee338d	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:08:14.912+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d918eb3c-d8ce-41e4-b9bb-42878d35bc22	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:15:08.31+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
30e85c7a-2d7d-4460-a0c7-f3d388c2ead4	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:15:09.2+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d2600ee8-69a2-4b19-9866-3439c4e57778	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:33:51.07+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
204be4c5-e96f-44e6-be06-4d4d49a2e378	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:33:52.262+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
58a5d8b7-e4dd-4ed1-8092-2c1cba88f0bc	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:33:53.668+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d8e6bb5a-67ee-4e67-9449-f56c032aa6e6	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:35:56.67+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
06044fad-948d-4606-8df3-19af4b744b9f	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:35:57.508+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6da7c998-f73c-400e-9812-fd6142a54fc5	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:35:59.191+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5238dcb4-c098-44ae-900f-e7eceaab8f87	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:37:18.27+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ac9ce103-6154-4caf-8735-319ed43a4b40	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:37:18.527+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0a5edbe7-5039-4863-b52f-2c28f7ac914d	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:37:19.311+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
19c6ff29-7183-4e0b-b27b-29b7ebd1bf02	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 09:37:20.001+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2abed756-53b2-4c6e-bf50-004855c2dd2a	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 10:18:04.065+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
58f85a65-296b-47b3-a129-be7a5592deeb	Jarardh  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 10:18:06.014+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
dc4c64be-ebe1-4cbd-8940-4b4c9511ae34	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 11:18:33.393+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f625b841-259b-4908-8db3-5c89409333f7	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-22 11:18:35.251+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4e5d3d06-614c-44fa-871c-ad4008e3c4f0	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:46:04.117+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
f1731f32-a5b7-4b81-8d5f-cb6ebc1c5578	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:46:05.203+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
4c85b8bc-9fdc-43a6-bc3b-122838840bb0	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:46:28.069+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
8f6de4ab-836a-4407-9b37-8e1df0ed9d23	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:46:28.355+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
614e1e52-3035-4095-b3a6-1e25ea1f2b91	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:51:43.74+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
3070816f-9e52-44ef-9c24-33a4f22313be	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:51:48.038+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
3007b240-6fca-486d-8feb-f03a4368a906	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:51:50.487+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
0a6d6d3a-80df-416d-a4ee-33192c6fa484	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:51:57.832+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
e9837566-ead7-4e3a-a1d4-1dc7299e5afc	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:52:03.85+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
e49c0b78-0056-49c8-8596-a6531989b0ae	Jacob Jo C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:52:08.432+00	3ca5b016-7c38-4391-a929-c7351709cd60	aea41626-3127-4b2e-9103-d3f07855a3f3
8af534c9-b15c-4149-b74b-b1903db85b50	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:58:21.213+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
002252d3-8710-47c7-b3c6-15b624252a41	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:58:30.007+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e5cf99b0-936a-471b-9e10-99db2a1852ed	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:58:58.366+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cb4cf7e6-a810-4faa-930f-cfe338283c3a	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:59:26.225+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
85f643af-4f40-46d2-bc9e-b211d1fee9a1	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:59:26.461+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
df9620d9-8a11-41f5-a84e-e6a33126f7b4	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 06:59:59.078+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6497a674-0d2b-43a4-8388-9edbb4458113	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 07:00:08.837+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0eeab122-0442-4ce4-a5a1-ef22c0c46d6c	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 07:00:09.031+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
aeeebf5c-65dd-40e1-b68b-438e0f3421d0	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 07:00:34.81+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
69a23a09-0ada-471d-80ff-fd220f496cbe	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 07:00:35.058+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
552786a4-7a20-4b53-9666-4410f72e0344	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 07:00:45.323+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8d4776c0-edcc-404c-83c2-868e4cfb82c3	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-23 07:00:45.744+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3ba9f0f5-d85d-406c-a5bd-7ff5bdd6f038	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:34.504+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b6d6763c-9b51-4bca-ae96-713b9a9306f8	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:43.86+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
029de239-1c0c-4b3a-a5dd-ad9c47b1c84c	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:44.264+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
033e241a-0130-4741-acea-7735b052a34f	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:44.895+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ec5f6de0-06a1-4872-b3a9-6af74c916b05	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:45.563+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0b0b5168-5eab-43ed-a824-4b474b418524	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:46.25+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2cb824ba-c820-4e16-9c9d-0627296292d6	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:46.927+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d2c825ef-9d2c-4eb9-8450-e7adc2a3b290	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:47.676+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b75a60de-2a3f-4e16-91f7-fa9664bf9eab	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:38:48.715+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
47946124-980b-43a4-bc0f-973d89f94f6a	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:56:20.565+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3deb0007-52c7-48be-9889-a9bd463b175b	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:56:21.652+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f2d5a1bc-c6db-4c01-80f3-fd2cf3aa94e5	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:56:22.429+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f1c95a19-a59d-4ecc-abc8-145dd09bd945	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:56:22.705+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
51b86454-a0cb-4fb3-b808-7c8de658197b	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:56:22.916+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8f138338-58fa-41b5-8ed7-7e2491268a06	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:56:23.078+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3d4d959d-6bd6-4bc2-a647-331aaf27148c	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:56:31.2+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6b183386-31aa-4a96-92d4-efdc3455b20a	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2025-12-29 03:56:32.47+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ef588a70-070a-4e4d-9b29-98111d8d9af3	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:24.592+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a9244e6e-178d-4c4b-ac77-5705423830d3	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:25.436+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4a92d86c-09fc-4ff0-be3a-b0cbe36ff505	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:26.987+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a66f0338-0458-4adf-99aa-9e2f656f0c1d	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:27.221+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
99b72a58-d461-4f50-bada-65ca52a581b2	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:38.122+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
425a37ca-a4af-4ea1-a749-170d9007a1ea	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:39.439+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
120683c5-8361-46d6-8598-efdfb0cbabbe	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:40.731+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
93a2cdc5-0e93-4996-bca2-fa7d8dc80f26	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:41.482+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a77da4cd-a0bb-4630-95ae-77ad507b1961	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:41.909+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e582c206-a488-4417-bcdf-21573b516b8c	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:42.058+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f1c5e884-6ec3-470f-b1ea-2d04cf67c269	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:43.14+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
21dcc5c5-c28a-4996-be20-14113b043e25	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:43.603+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2d9350d1-209b-4cd7-9325-609c7036b48e	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:43.376+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4411b5dd-c067-4da9-a984-fc8c5e5b9fe5	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:43.897+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
147833af-7910-4fa7-bb56-9377e60c4523	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:44.738+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
feeabc79-95b9-4486-9d9b-3e9907dc33e8	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:43.486+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b8d6aef7-7724-4b27-970f-131bdbaa800d	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:43.729+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a1ae2585-84b4-4338-a093-ae9ed99a7d68	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:45.139+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6bfee8f9-abf1-4bdc-84ab-480d7c29ac3b	Jarardh Jacob  C	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	::1	2026-01-01 09:42:44.227+00	3ca5b016-7c38-4391-a929-c7351709cd60	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c9adbe5b-ed53-4ddc-b2b0-d9be27458408	Carlo Ai	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-01 10:01:28.021+00	d5ef4894-5829-418e-8e08-e8763bec536f	f9fce64d-faf4-4195-92eb-e40ed2253542
e44a5047-cc95-4d9f-be18-4fd6fe291eef	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:48:58.747+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
286a8faf-5d5e-4dcd-8e4f-849f3a05b4eb	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:48:59.493+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
56b4a2d5-94bc-4a3c-9b7c-498a2b155a9c	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:10.884+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
02ca7f9b-b298-41bf-81d0-8b1638d38557	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:11.133+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
77742264-b9e9-4f0f-9cd7-f71c68079822	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:12.065+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
72f1bd04-2aa2-4818-b8f9-598c5376acc2	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:12.801+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7b1da5dc-261e-4f99-a93a-5ace593ce9c3	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:14.661+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
862103c4-5411-41ca-b637-28b0d4d344a0	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:41.034+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c563f1fe-0147-4aa6-b078-039b1296081d	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:45.387+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b3ecab1d-d6df-40f4-bb24-0f8e51496358	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:46.947+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5252b766-f386-4a18-89d0-7d0bef4dc3f6	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:47.835+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d59e8232-329e-4b72-9b71-4dd140de399c	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:48.718+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
efd918cb-0a85-4782-8496-bf5a196bf1f8	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:49.474+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d2ffa691-dd2b-44c4-8c97-acb88ee4aef2	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 03:49:50.047+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
629433d3-c2a0-45a2-a023-31029cd2dd89	Jarardh Jacob  C	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-03 04:19:14.799+00	d5ef4894-5829-418e-8e08-e8763bec536f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4d2b19fa-2ca1-4cba-996f-c5de4e31213a	Carlo Ai	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-06 04:07:00.559+00	d5ef4894-5829-418e-8e08-e8763bec536f	f9fce64d-faf4-4195-92eb-e40ed2253542
2521f845-a327-4965-b09a-c0fe1af3555d	Carlo Ai	Test Sample E-Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-06 04:07:47.993+00	d5ef4894-5829-418e-8e08-e8763bec536f	f9fce64d-faf4-4195-92eb-e40ed2253542
d506e364-1151-4952-b503-f76e515adbe0	Carlo Ai	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-06 04:08:23.554+00	3ca5b016-7c38-4391-a929-c7351709cd60	f9fce64d-faf4-4195-92eb-e40ed2253542
548de410-5a14-4cda-9e33-5d5bb2fc0cd2	Carlo Ai	test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-06 04:31:01.148+00	3ca5b016-7c38-4391-a929-c7351709cd60	f9fce64d-faf4-4195-92eb-e40ed2253542
f8d705f7-e1a2-45ed-a7f3-0d0bd860bbc6	Carlo Ai	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-06 04:40:18.625+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	f9fce64d-faf4-4195-92eb-e40ed2253542
e5d6e593-a321-4862-af20-3deb8bb51442	Carlo Ai	mern	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-06 04:40:53.895+00	7f6ba210-3f7e-40fc-ba24-d3d1ebb0861a	f9fce64d-faf4-4195-92eb-e40ed2253542
50771477-3a31-45eb-b2c8-6c6c6f4809ae	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:52:56.376+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
74da70a4-a566-458d-978d-035921a95dc5	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:53:03.351+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
dac1791d-8797-421f-b77c-6da131fca9a1	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:53:10.16+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7c7801a3-021e-42d9-b19f-184456a5a601	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:53:27.673+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1303f5b0-3231-42c5-a0f3-3e4b86886ba3	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:53:35.317+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b98da0d4-6517-4f37-8bea-15d2f24023e5	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:53:35.743+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a63fec67-e254-4539-82d5-04c39ba94a08	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:53:36.826+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
08ad66db-999f-490c-b6a3-e0459f594741	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:45.604+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f5f64bae-a0da-475b-8a55-2d8bb94fc82d	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:46.213+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d06c334e-a8f0-46e4-9094-3ff92da022ec	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:46.915+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e729d71a-d272-4c86-b1e4-acb9360a8fd6	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:48.657+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
316186ac-0d2e-4185-884b-5e296450dfa3	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:55.393+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fd5cbc41-b391-42a0-8237-a3b4048eb941	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:56.069+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
05e02988-9081-4865-ab88-dd60faee4de9	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:58.459+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
790adee4-45d9-4a7d-acd6-6b5ecb7b841c	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:59.078+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4b94dd00-cdfc-4a93-a6f4-99d3a7faafac	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:59.45+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4360ef20-9171-4c34-b348-b8cb5aed27d8	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:55:00.031+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1b5aea0e-faf8-47d8-98a4-47d63d5526b7	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:55:00.818+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b1d95fe5-2332-41c3-808e-e0e9905c45b6	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:57.324+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fd91453d-03ce-46f7-9b95-dac135b23339	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:57.669+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
943ea666-7984-4dd4-9942-678140d90878	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:59.197+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e42bcd09-62ca-4ce4-9399-dcb03ecc31c5	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:54:59.814+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
902b729a-b015-4a5c-b67b-7df6de4fcf99	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:55:01.04+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5bdf5573-0f1f-4242-9fcc-4177a0713235	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:55:01.375+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
36c91a45-d657-4fb9-9767-9d2fd3475841	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:55:01.556+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ced87ed1-bf32-4432-8530-655dfcdba97f	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-07 09:55:01.783+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e5b46962-e315-414e-81cc-33ed94906779	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-08 03:28:23.325+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
eec608de-54c1-4ac6-a16d-749ff7752245	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-08 04:01:57.044+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
18eafb18-fe8b-4fda-bcde-64396ef1f79e	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-09 04:32:26.814+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c780f4de-def5-4433-83b5-73faf5d5bd1e	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-13 03:38:11.027+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
1ac90072-4e32-4f4e-ad95-ff7a98f7ef1a	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-13 03:38:54.04+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
d24d4890-0b7b-4e96-a2c2-a7ff95d3f714	Unknown User	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-13 03:39:18.691+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
37ac519e-6d0b-40fe-b3d7-73176d065da8	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-13 03:40:52.121+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
b45aba52-5ca6-4f47-b7a3-e3c78c6c5f34	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-13 04:09:16.667+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
13465b11-7047-4299-bf4a-e67c3f150b6c	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-13 04:15:03.566+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a0c77d79-1645-4f76-bafa-103cbb7583d3	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-13 11:15:15.389+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
1bb0a870-7d06-4962-a996-71b43abad84f	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	::1	2026-01-19 10:11:44.997+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
c1e330a5-dd8a-41ff-8a3b-680ed3ff22a8	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-04 03:28:29.936+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
e41df7ee-7674-432c-ac31-0da9d28f0ca9	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:27:39.881+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
481ebdbb-d821-454f-ac09-eedd91cbeb2c	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:29:00.682+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
96b77e55-6b2b-4da1-a751-da9e6308de66	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:29:39.2+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
23b2deac-df14-4e60-a263-33241c7e69b5	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:31:33.086+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
04f16a56-e74e-4a89-82b9-2a181d87f593	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:32:18.852+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
aa6b82d2-09d7-4106-9238-f12afebdd227	Unknown User	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:36:12.87+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6789114e-026f-4d77-abab-a661520e6686	Unknown User	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:38:43.057+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2582eaa1-a9ec-48ff-a2bb-1dbc20687b58	Unknown User	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:39:27.711+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c4fd77a9-972a-43ec-9181-0448fb156a3b	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:40:48.446+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
2f33b346-35c0-48c2-bdd0-ba709cffab77	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:41:02.115+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
d1df5acf-789d-4fbb-ac91-b9c4095fcee2	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:43:58.001+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
1cb9be4f-69d2-4ce9-a6a6-38799409b913	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:45:45.258+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
a53fc26f-cc5e-4161-aa28-e9f9de6458e6	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 03:50:02.408+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
f7995b86-19d2-48de-a15f-7c0a28f3a67d	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 04:01:39.57+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
d2c616ec-fa80-40c2-a1d9-88d25a7e6fbe	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 04:02:39.85+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
7e5a5da2-b16a-4be2-9ee9-792dd632456c	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 04:04:50.055+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
9f37bc5b-8a6c-4da4-b9c3-0d13a693e405	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 04:14:18.775+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
98ee4a3a-3612-457e-aad3-ffb4e994ede8	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:10:40.303+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
7fa23681-e95d-4448-964a-52d8ac0e0434	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:11:49.694+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
26981879-d5d5-4be4-a0e2-f104f6d83f80	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:11:59.801+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
33989db4-b79c-4774-aad2-7d2e431fc60d	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:13:38.355+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
7c839b41-02a5-4ba7-87eb-85df52025914	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:13:51.405+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
8b0d56ec-5c89-49cd-bd7b-0477f5e4ef52	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:14:48.953+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
1292a1c0-503e-4c7d-a902-6250f4024160	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:15:16.059+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
350d0050-338e-44ec-99cc-8e0347a9de9f	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:16:57.835+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
4a456497-6c2e-46d6-95e4-a7d456633583	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:35.609+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
883d4785-94ea-4791-910c-bc37496a09d2	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:36.37+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
ecd86676-212a-4640-bbd3-fe84f400b01b	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:36.502+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
e3f37d97-0711-4b1e-ba6e-db7a424d3ada	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:36.818+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
4d462777-7e76-4264-8173-91e2923be072	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:37.152+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
ff4e7ed9-6649-49c8-a6d9-d3ac3149b072	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:37.538+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
7c20b16f-287e-4a53-ac3b-086ee5e89f35	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:37.755+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
5b13ad3b-fcfe-4400-9db6-17b9732e8120	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:38.076+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
e32f9109-9ed6-4242-88a7-3c2213a59d69	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:38.311+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
e907194f-ea6e-4f8c-a884-fd355694bc14	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:38.618+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
7bb7e81b-fec7-4d3a-9d00-fb788a66c636	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:38.733+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
554aa21b-48d6-42b3-bc6c-755b630558d2	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:39.155+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
062d05d9-58af-4054-8e06-2cbd1d0562f9	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:39.259+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
0591c604-0d12-46bf-84de-5a9a51c2ff70	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:48.304+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
65552487-fb59-46a0-a06f-d4e97f05ee93	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:48.799+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
770c5eef-9e87-4d4a-8137-9506ae0bdfdd	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:48.925+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
e4ceb591-3a0b-404c-877c-19ddc7b8c31d	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:49.072+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
78704671-9e1f-4fcc-856b-2da23f8ffe1f	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:49.187+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
70d16d52-b460-4ec0-8da3-14ff5efb2b40	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:49.251+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
c39c0b5f-7ffc-4e5b-bcf6-c8a9ee764b21	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:49.494+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
dacb8c71-9209-453a-937b-0179b0b7a7ee	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:50.004+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
83a52d69-d814-4f00-9c17-72d8e81d98ac	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:50.114+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
7083bce0-1b23-4967-a5e0-d369d177591f	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:50.236+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
fcfe4f2c-7359-4743-a241-0fc3969bc2ab	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:18:50.388+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
14d84228-4d09-4649-8c51-2ddcf4fb52b7	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:19:03.287+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
60f8792d-5e58-45ee-bc83-4599d0421bec	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:19:03.314+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
2b296c1a-3805-4a8d-b99a-08b80e366092	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:19:03.614+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
7ae18b0f-808c-4bf6-b044-f75174f3eb77	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:19:04.538+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
4264a34a-534b-40bb-9abf-ee9cadd79d1a	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:19:03.658+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
df19c159-15eb-4565-bd30-25bb017a1359	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:19:03.828+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
1e9770c7-d2da-4291-b68d-77bbc10d0b1a	harith	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:19:03.987+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	782c37df-f571-4390-bd69-fefdb0e13cf5
4651abee-f400-4903-ab1e-0e0b067fbab6	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:34.738+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2cbfa092-e363-4392-afae-cd3c4b2d1a0e	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:35.066+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bf25a414-8ad7-4034-87e4-af14b3adfed8	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:35.22+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bb978832-c86b-410d-bf63-25da2801a563	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:35.365+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e1bf7990-0da6-471f-9785-3779e6c40470	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:35.514+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
26a0a9ba-249a-4df1-9d74-432e7ffcb06a	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:35.681+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cc129f0c-fc63-40b9-a7a1-0746e8fc9cf2	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:35.88+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d8db6cda-1728-4017-9406-247efd5f2065	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:36.085+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
656ce9a1-bdd7-4afc-9833-dda05fd2c9e0	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:46.401+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
82694337-610c-44b8-90d0-01387e79ac21	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:46.488+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6a3e527f-1671-43f7-b42b-722ce5ba0c6c	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:46.658+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d913cde4-901d-45f3-be81-7162a078ddf4	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:46.779+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
15b0cfbc-86a9-40c2-943a-c33132e28f66	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:46.941+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4eb761db-fe64-4b76-8b03-d9e29f89438e	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:47.128+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ba8984f8-46be-40ea-b7e7-d88f6022d55a	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:47.266+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3644564e-9444-49b7-a8ce-cc722c0d9d3c	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:47.373+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
34c6191e-5f84-46fe-96cf-cbde235c337e	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:47.549+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
980df4f1-0727-4440-adf9-23f0273c962e	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:47.722+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
664a4e4c-7183-4c1a-9be6-2d6d152c5451	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:47.882+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
05fc801c-612c-4415-b98f-e5d43b2903ea	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:48.035+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
44a02624-cb9e-46d9-b234-0758efaf996c	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:48.185+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b07679bb-d14d-4da7-9d65-f8b9620fbce0	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:48.356+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b53ad666-e349-4f7c-b271-8c44d1c2bad2	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:50.496+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9365c2e1-d8b8-4b4d-a73a-3b05d5c746fc	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:50.496+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d66a7eb6-2c4e-45fb-8c12-3ec36ae1e57b	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:50.597+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
79f0eb7e-1869-4d32-a6f2-6854459e2305	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:50.596+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
34fff208-03ba-469f-a04c-1140e1db7cfd	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:50.598+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ed07b096-30d4-41d5-87c8-43c405689874	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.198+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b5937921-29fc-4050-84dc-913d1e452074	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.199+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
40bcef6e-0da8-4b26-93d6-267702b55cab	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.201+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
73005ca1-f157-4032-ae9d-92702e254e3a	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.293+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
33512f40-d786-4138-b453-e043bbcd326c	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.295+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b8ed804d-1392-4dfd-8a08-5f4aa4321c10	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.29+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a7a82b24-ca78-4f2a-8b6f-551c350f933b	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.636+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b03119dc-66f2-4307-b790-3963223e283e	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.638+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
32bda19f-8704-4cde-b48b-3d9969185a08	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.291+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9c6eef16-0daf-4df6-bac2-61f8ad695ca2	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.364+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
47615f72-0e28-4bac-9484-0799662d2c73	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.527+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
472ed77b-f581-4c06-95c9-10cb72569312	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.293+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8fb3e294-12fd-447b-a0ea-aa882752038b	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.528+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
711cc2f5-9b33-4ced-84f5-3999661ca9b4	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.297+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bff89201-b4c1-4e0d-bc88-5e7e142883cf	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:22:51.594+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e6e808bf-c4e8-403d-801e-4e9c30e1c0ec	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:39:38.005+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ecd5b85d-bd28-493d-addb-7167ed8acaef	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:42:40.297+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1c159071-153c-4e15-bacc-0f8f1e7eb97d	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 05:56:51.97+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
026ea895-da29-4bad-b3fa-74aa4dfb2cf4	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:04.829+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5585fa85-48a1-4f45-8599-cd20df410c8e	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:05.166+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4529df9a-2c3b-458e-9dd5-3e1c407a4ac4	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:05.303+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a16a9638-033e-4107-9b65-302015ffe7a5	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:05.499+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d093bd9c-2994-4747-8ca7-9c9c0284bb48	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:05.607+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6e546afb-4696-4f2a-9927-5689eeae7745	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:05.773+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
95e0b849-55db-4e4c-a89f-332289b7227d	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:05.946+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5372e14f-735e-4425-8a04-e54d956b9e70	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:06.126+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e788440a-0a6f-473d-abc6-88e4014606e6	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:06.238+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4f3a8e2b-50e7-47ca-8a1b-9fee22d2c133	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:06.422+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
848bc856-acb7-4787-9a57-a4515575306d	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:06.623+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
26fc0c5d-0ef4-405f-91ff-d1ad309b5240	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:06.775+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ad647add-9547-4255-a877-fb52efa5d8a0	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:06.95+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cbee1a7c-29db-4926-a5f1-c2806107a0fb	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:07.104+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
40ae6526-2ca5-40df-8ce0-4d264fb09045	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:07.277+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
522b9460-e473-4836-a80f-220056b1627c	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:07.427+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8de15987-3e5e-4278-8685-bea3a33606b9	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:07.616+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
62048cb2-5c7e-495d-b064-8b73d9052f13	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:07.774+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
67874d94-f89f-4ce3-9b9f-96991ca41f50	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:07.969+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7c484e5a-6d79-4ac6-bf73-08654ec583b9	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:08.717+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
53424139-76a0-4e96-b7e4-b4cbc21bf187	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:14.617+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8a1d9b3f-13fd-45b0-b86c-998f08a26174	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:14.965+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
88a690d8-38dd-4f4c-92c9-c8e4291fabb8	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:24.414+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2fc641a8-4329-4f7e-8884-a5de832ed325	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:24.56+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0b8130e5-f4be-4ac2-bf75-d192dafcfb87	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:24.655+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f6f0b69b-cd31-4e1d-9abd-4e8ba207fb83	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:24.688+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
da48cf8c-8a90-4234-afd8-5e2756e1a594	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:24.757+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f7abcbf2-e52d-4b68-95b1-9cdbcfd33a14	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:25.532+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
15628db2-7ddc-4fc2-8fc4-59fcc98c9f1b	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:12:49.564+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f4e8fa8b-aadd-454d-96e1-41301be7b955	Jarardh Jacob  C	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:17:26.477+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6017c402-841c-4273-b015-ea23f3d9e017	Jarardh Jacob  C	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:17:26.791+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
97d97c05-bcac-45df-b977-9bb8f9051bf1	Jarardh Jacob  C	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:17:26.899+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
27daf2f3-6665-439c-924b-bd6cccb47d5b	Jarardh Jacob  C	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:17:27.088+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6a6b3a1b-5583-49f1-a96f-b7f416991352	Jarardh Jacob  C	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:17:27.298+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5870e1d1-c451-461e-87fe-cf06031d5c09	Jarardh Jacob  C	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:17:27.487+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
66430f11-8658-47c9-b00c-9bfe2baca9ae	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:39:54.749+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
88467b3a-ebd2-4f09-b0c2-1002f99c51fe	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:19.636+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
050f9b8d-900c-4cf9-bc4c-6483a5e07011	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:19.806+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
1df4aad4-34d6-48aa-a440-6d37b79f8e7e	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:19.969+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
53891bb9-05e3-423d-9c3b-5a2ee12777e6	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:20.072+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
7300fce2-b4f4-4001-a343-be50d3ef7684	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:20.252+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
06660ae4-7dea-4af2-95c8-cbe9f7669dbb	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:20.531+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
f6ffa57a-334b-4e8f-ae9f-8d70acc6a34a	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:20.579+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
70cd62e4-6be5-4da4-b9c4-fadf5190ede5	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:20.787+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
c02f1e58-e848-4116-b4fa-b4e21a691498	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:20.873+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
16b03147-67ad-49ce-828f-d45a1a15c34f	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:21.018+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
6bed6cfb-ee7d-4154-8c2c-c5ca369984cb	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:21.188+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
7f26c390-123f-4043-9cf8-937f9515ba3a	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:21.343+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
a88f5659-8454-467a-83db-52c0dcf5eb9e	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:21.514+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
346a3b1f-03b8-4a05-b224-4c87e3196f7e	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:21.812+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
e4f04846-502c-4323-995a-7416652bf2e8	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:22.228+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
0f3af0eb-bebf-4749-9b4d-6a3d309591e9	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:22.391+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
f1928e82-fe31-4a42-849a-f68fe37c62d4	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:22.557+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
900b7429-375b-4884-822c-fc4215c05f1f	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:22.659+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
78e41cbe-9764-402f-98a0-8f162b21ed7a	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:22.83+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
ae20c430-9fe5-4418-ac56-5df8ba8930b5	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:23.001+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
26c8cc1f-4ef9-40a4-823a-a48b3351003e	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:23.102+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
95e745e6-2e60-41cf-b713-bfe3366d99c1	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:23.279+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
c220ae84-ee79-4c64-9127-7d146aa55398	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:23.438+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
435d30d6-008b-4b70-8952-53e5937c5b15	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:23.609+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
fdbaac8e-eae7-4f39-b451-7795f77c20f6	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:23.811+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
bd2cb36b-8d82-4ca6-8b38-396c2de17893	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:25.818+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
2029574f-579a-4142-8c67-afc4b4fb3ca8	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:40.955+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
19e951c3-3a0c-4293-9778-10f10865d4b7	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:40.969+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
86cc4d4e-f3d6-4cb1-b4b0-ac899e172801	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:41.092+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
cfafc7b1-9965-46ca-b599-d578533e1ff1	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:41.59+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
9092f7aa-c717-435d-ae69-1ed67a99cb5a	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:41.87+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
a80cd49e-4c2f-4f02-b401-a33e9fbd527b	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:41.132+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
dc5587e7-66f5-4220-9ceb-a1a5fcf16b38	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:41.32+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
f0403308-6776-430f-91df-256f505b5833	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:41.869+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
219b53ab-e916-4ad6-b2a5-5f083b14ff27	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:42.042+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
b6e0f58d-c12a-415b-9e85-866d53290584	Kevin Jo	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:40:42.854+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	f8433f32-428c-4011-8cd0-64ce50fca8f9
1af78139-1652-451b-8cde-eb617c275d6a	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:58:05.885+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
3c320908-6948-4081-80d3-1f7b54d5e09a	harith	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 06:58:36.999+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	782c37df-f571-4390-bd69-fefdb0e13cf5
a1b74598-ee2f-45e2-a602-00952a5315eb	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:04:20.27+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
90553f79-dc83-4e30-ab43-f362501af1c5	harith	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:07:20.872+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	782c37df-f571-4390-bd69-fefdb0e13cf5
415ff375-ed22-4aa6-9424-8f2aa067af00	harith	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:07:45.35+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	782c37df-f571-4390-bd69-fefdb0e13cf5
67e195f6-4e16-4e0a-9998-2ff7b23051f1	harith	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:09:19.984+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	782c37df-f571-4390-bd69-fefdb0e13cf5
4c8276d5-c2d3-4840-92ae-adb64a6d38ee	harith	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:14:58.576+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	782c37df-f571-4390-bd69-fefdb0e13cf5
6669a757-e76a-4099-b052-f336a5588fc3	harith	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:14:59.328+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	782c37df-f571-4390-bd69-fefdb0e13cf5
565d7fd2-3d3a-4120-b708-11b1ca2aa28c	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:42.881+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c4799bb8-3dc3-43ab-8c28-5be83f213908	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:43.334+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d0e3484a-c37d-47f5-bb9e-6018507dbb5c	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:44.09+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
880c790f-1505-4da1-8240-a8cada621a2f	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:44.261+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c98174f4-25b1-4f80-8ada-ae747e0dd11d	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:44.397+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e5e0b389-7a3b-45e9-949a-fe80868b2082	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:44.54+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
91a90814-d54f-48b3-8cbc-002dff23a847	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:44.704+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7b30e993-c16a-452a-9074-6de8c736f77a	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:44.868+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2d03efbf-748b-4273-bb9b-d5f99cf16a1a	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:45.074+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b0787572-292d-4e6a-9484-1ca6569095c6	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:45.233+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
41ecbc85-e8de-4f42-8328-92d3e4589d99	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:45.409+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
adb43a3d-7b16-49e2-87c2-ab928c59a555	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:45.727+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d81f1742-9d42-43ee-9ebd-12644ccdce06	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:45.895+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2581ddd8-c9b3-405a-9d7a-d7125128c7b4	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:46.051+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
dae4194b-19d4-4c29-9761-c1a35247037f	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:15:46.12+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2d3e45bb-f03b-4ec3-b053-b33dc1164ece	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:39.721+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a42ee1cf-c069-4917-bbc0-cf7a15ad5521	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:39.773+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
eb859890-f686-4f9e-b304-22e8fecb10cf	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:39.918+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a65b70f9-2e2f-4ae3-be35-a3f7e5199b86	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:39.963+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
05b01a68-e6d6-471a-b716-1b4d8b6ece68	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:40.061+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e8bbb62f-734b-43ca-ada6-f72935e424cd	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:40.236+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
17da3961-fc8a-4ca8-accc-645593594a6a	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:41.121+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
60bc5a32-f6b2-4b1d-855f-d9d2bf831174	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.014+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ba9b2b6b-7112-418e-bde6-ea5a20384ee7	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:40.773+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
be17082c-3f05-4c30-aa4f-d954508cf3d6	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:40.943+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ea0c46d4-62ce-45c1-ba82-ff9c3f76c4f6	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:41.277+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
92278164-5000-41b5-9d37-6c82766842f0	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:41.707+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
325ef081-4a2c-4098-8111-d41740ed68ae	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:41.969+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7febf7dc-d1e2-4a22-b5e9-9498e095d6be	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.013+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cb77bc8b-7291-471c-8477-10056dd53183	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.113+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9217d72a-9c4d-4510-9044-8960a8bf00ca	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.018+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
04a54b2f-38fa-4d32-a214-03c125bbdf8e	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.293+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
46b62c88-fe0e-4f12-9b50-9477f668b815	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.02+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4a232119-744f-4809-bf8f-07f5fae8d2c0	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:40.949+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d1e9f548-10bf-4c4e-b578-bc14d4722185	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:40.998+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0bf3cb0c-d811-40f9-99c5-3997737433ca	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:41.417+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d650681b-92c8-47bd-8195-995f56bcd6c4	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:41.791+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ee6ba608-0ca1-461a-bf27-797e66f6ff18	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:43.811+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4aece1dc-4b5e-43eb-a851-881695be8c13	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.016+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8bf4e465-9ad6-41a3-9ea2-f6d952549c1e	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.115+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9dacdd6e-eac1-4354-b7a2-81d4e7f5c5e7	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.212+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d10c8560-11c7-4f41-9820-3c9c51b1f715	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.116+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2ce8a9f8-7eca-43f6-bbeb-54f049de0f44	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.615+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c251da3c-a054-4bc0-96f3-1381fc1357ef	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.015+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2d890167-cb3d-4231-9409-8e686a5c61a2	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:18:44.178+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
39fecec5-c45c-4c9d-b8a6-223f8e26ef38	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:46.529+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e038891e-e2a0-4fc9-a0d4-8366913a5ddd	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:46.579+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a6664bfc-2258-4fc8-86c5-48c210bc07ff	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:46.68+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
59e859c2-b574-459b-9dc2-56b84030ed14	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:46.773+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
10bedb0f-7edd-426e-9fec-cac55ea3d271	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:46.878+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f7707b6b-d202-460d-9431-17753b380fc4	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:47.089+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
44f0a7ff-0cec-4fff-9586-b6c555ddf07d	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:47.204+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
279e25e4-502e-4f2c-8ba2-fab52807e73e	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:47.361+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d5112993-1b51-42d6-a77a-5bc1967769ce	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:47.522+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
022e6049-b19e-49a4-ace2-6eff279dbabb	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:49.932+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2d19170f-2009-45ea-a138-81230790e428	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:49.933+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
33f3c5a1-4916-459f-8a45-dd1a19c533c8	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.029+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2b395aa3-659d-4465-a7d7-e0a39ccbb62e	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.026+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
01e9d800-2792-47cf-9b1a-33a5da1fc7a3	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.131+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5072d41d-7e5b-4993-a493-b1ef95959f89	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.329+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ce2dd5b7-5952-4798-96b5-eddaa8d08085	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.331+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
aa47b9f4-698e-477c-994b-a43f275a8aa4	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.326+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b57160ee-f00f-49fa-b251-1817e141e0d1	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.03+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9db19461-1e42-4e0a-a27d-bae0aa2f0a25	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.533+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
49af1db2-567d-4455-a009-151cef0badca	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.725+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
343db6a8-ced6-48dc-8147-2c62a77b00bb	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.738+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6c73e235-a8c6-4faf-9ede-ba9a189ffcee	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.732+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3b2bdf1e-56b0-4260-82bd-121c2691f913	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.737+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2de60ac4-eb64-4fe7-a046-200ce5e37941	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.741+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8c24ecc6-5ef2-4163-8fe3-ceee8df490de	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.826+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
973236e3-f505-40c7-a388-29b24c66a84b	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.838+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4c3cdded-372d-4e9b-b983-9715b15d99ca	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:50.839+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bf924ca1-f676-421c-872f-1461ef8c4fd4	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.126+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d9b0f058-2475-4560-b5ac-41525d345319	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.226+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2108da59-d2ae-4a7d-a16a-d832bb2d324b	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.228+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
dac74b45-7aaf-400d-b8cb-d21ec67673d8	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.227+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4c4ee467-51be-480d-862e-f32c3c07e435	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.831+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d54950d3-8c8e-40bf-a7d3-efcecaf28643	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.027+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8bee1da2-91c8-4d07-a4e5-7e8c96c7e5d0	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.425+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9d57803a-1a4d-43e2-b9ac-6330476936ab	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.731+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b443c97b-e176-4f85-8a29-4f79846831ed	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.858+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1d023f80-429d-4de4-9c8d-21f5f21ec7ce	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.229+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
79096f63-5523-45c0-9bbd-a84ac5d3972c	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.733+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9968352b-82c8-45ce-97ea-2ade2fc469a6	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.6+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
53e9b9ee-f21f-4b34-8b09-4946eaeaa8ca	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.698+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
512fd573-cc6e-4aa1-8f4f-7eb36cd430a4	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.93+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e37e0712-e760-4bc2-883e-91bb24172dad	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.23+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f4cb0f66-762d-47e6-931f-2be2fd2e27ce	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.735+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
987ac96a-74c0-4739-90f5-57cf20ed0b70	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.134+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
60d87d64-b7b2-48c8-8775-d1314d2e364f	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.432+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b9733085-aa5c-4670-9427-6ee503055650	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.699+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ed460f2c-cccb-441b-b135-f6f730d02055	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.727+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
944b3cf4-d24f-48d4-b377-fd1d3b6e8161	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.868+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7994b7ef-78d3-4646-83d9-f1b3f8d6af7d	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.537+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e06e9b5e-eaaf-4177-8694-29cea295fbf3	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.631+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b9f174d2-7486-4d82-81cf-09e43fabab0c	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.135+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c1518b40-a4a4-470e-806e-183d9bece9be	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.601+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9bbe6411-8ec6-4dd2-8f4c-58e8fef448d5	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.725+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
682656e5-8167-4b02-a292-f9e0fcb020e6	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.732+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
35863f65-03d9-4bbf-af06-b85f67512b85	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.536+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
376ed300-eda3-4985-85d9-13bed917d440	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.43+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c670bb24-e590-45b5-9062-da40e59c7e2e	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.729+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d669f01a-7de9-42c0-a9f4-cb4d8e802039	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.63+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1e93acfd-c72b-44e0-bf3f-d2277cd8f840	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.63+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
8932ac2c-38f9-4f18-9b5b-a2d62e2f913c	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:51.734+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
99a95cf1-847c-488b-a43e-89e9c919470d	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.138+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ffa85d38-a6ef-42fa-94e7-beb722b481cf	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.426+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2ee0b921-cb86-4a6e-b795-cf689d377082	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:28:52.935+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
340ca836-1d45-4d00-a0ca-50f4828af70f	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:20.983+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
e8a4f51c-955e-47d9-a4e6-7be8c0f299b8	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:22.149+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
97330c7f-2715-4491-b6e0-bbcb6f5200c5	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:22.251+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
51ec7591-f8f4-480b-87a5-8a80f3f0a078	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:22.275+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
47402dfb-87b6-4384-b1a0-e6e0fbb668d5	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:22.942+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
e4aaaa75-1216-48d0-bd7b-eca179e570ac	harith	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:22.962+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	782c37df-f571-4390-bd69-fefdb0e13cf5
e6e91e4b-d747-4688-8655-d66da24ea73e	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:50.33+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9e1c57d9-093f-45ff-95d6-5504ad4114b2	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:50.331+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
aafd9832-32e8-4780-9a7a-0d845a8f8d62	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:50.631+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
960672e2-76d1-4014-b261-9fc75d435535	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:50.725+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f4d08e44-f66f-4f3f-a720-0dfd66cd60c1	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:50.728+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2e21543a-987e-4d46-bb37-2f9e90a40f50	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:50.733+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3dc6f27f-0fe2-49f4-a5f0-ef829d547a5e	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:50.832+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
502cb126-3519-4df4-b627-cf218ad2db07	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:50.833+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
447a722c-6219-43f3-90fc-965f23d5800a	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.126+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cc5389e2-2467-4722-b055-1f5cbe1a01ae	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.128+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6a5aa738-e688-41ba-8add-42a435acb659	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.431+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0a9d260f-3738-450b-b17b-9a3a83a147fe	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.432+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
be7dbdef-d279-4a89-abcb-344519a1c4c9	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.526+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ffb9c10e-c216-405a-b201-b1495b66fb54	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.528+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4a9ab1cd-163f-42c6-8905-ce4c3542bfd8	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.525+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
35493088-5374-4e08-a1fb-a00c35a133a8	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.129+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
10687e61-eadb-4fa1-991a-1d2c8b0461ee	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.229+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f02b1cd8-b880-41d3-ab00-c6fab381c4b8	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.131+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
66763f01-8747-4b40-8547-9ab1cf02dcf0	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.132+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2e2839d0-3291-4851-bbd4-024dce4ec942	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.233+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6f32dd3b-cde2-47e5-8f18-dc0719c0234d	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:51.928+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
987b667d-2607-42aa-8f01-b33f14f491e0	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.127+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
79ef803b-2565-48cf-ab95-f9da267f8c6f	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.429+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
b0d1fe0f-3ecb-4220-bb3a-6edf4a9f024c	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.431+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2d2698ee-2edd-4a29-b446-5c962d77d806	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.433+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4ff3c335-d7ee-4a35-9dda-ef5617067a07	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.43+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1d57c0e5-e448-492a-ae03-ad6300d0f093	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.034+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
48f01b4d-52ac-4599-92c3-1f7c55068d23	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.233+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f0d08194-5068-4efe-8e7a-afbf5617ed03	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.427+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d6587aa4-fde7-4722-88b8-e3051910f02a	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.725+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7e1649b5-1bef-4a4a-8193-1ba99b456d39	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.829+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d769395b-ec41-4732-a6ad-3f9482e9aaf7	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.026+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f79248af-6f11-4f5c-b12d-7dc2e5723279	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.326+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3050f580-82ca-4dbd-b1e7-198b199d90ec	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:34.732+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d7520ec5-9004-4fb0-94bb-22e20c1f8d30	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.728+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2475fb0c-1ccf-45f5-b5a6-2de80ee2a70c	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.825+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ddae1e9e-7e5f-4d30-8b44-dd852205ce6b	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.528+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
88f3daca-fbb8-4ba7-8bb1-a7ca05f8b36f	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.934+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7c69b3a6-eef1-4111-936d-c32dad365899	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.132+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1959ee0c-c06f-4e83-a3e9-1d105b23704c	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.23+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9ee49f64-86a0-4802-bef8-4dd5385cc9ba	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.529+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2a75fa01-373c-4a0b-a71c-7bd4da38382f	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.864+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0644ad66-129b-4799-bad4-f9b33892289b	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:14.527+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ac5f1272-e648-4c64-850d-3d0684b90ade	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:34.631+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4d92e052-18af-497c-88f3-b463d4056ee7	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.224+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
55ba11df-5a4d-46a1-93c1-03bbe02e63cc	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.626+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5f4b0a27-a6a9-404b-afe4-62739f0d4378	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:34.924+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ff09d14e-120e-4173-85da-0b01fc310bc0	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.797+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
444fb2f0-f6c8-45d1-ad04-85d5c2a1dba3	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.893+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7165afc5-6bbc-436d-b586-c6ad63a8997a	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:41.281+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1bc2f12a-1cbe-4b2e-9ad7-6581ae90723f	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.53+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
350d1293-b798-46fe-9d3e-a1349158365a	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.933+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4f39c3fc-c952-4def-9373-6aa28d63b11e	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:16.252+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
eaed98fa-9d8e-483b-9e5d-b43258b4220f	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.326+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f2ba4398-5c03-4cec-a97e-8aecf2172911	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.799+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3c6e5e89-29aa-4b6f-95ed-03071a1cecac	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.915+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6c2a1fec-93c3-45a3-a9a6-cc4da7dd29c2	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.624+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f3a2ed72-6b30-4eb4-9a5e-83ca09a6d704	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.035+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a280bae4-16e1-4b6a-bbbb-227b62bd0672	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.232+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
33a8a8d6-57f5-463a-9ff7-4d6ac1834127	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.333+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
159318b6-cf6d-44b3-96b4-54b214f3abc0	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.637+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3b46157f-a10b-4802-b8e5-bda89f86f84a	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.827+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bb1467d1-9c22-4efb-aa64-d0dcdbcf511f	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.126+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e8b75752-28d4-4833-86f6-23371b4728f0	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:34.63+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a736e1b8-e9d8-4ec4-991d-aed5cc7044bf	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:34.827+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f7a9272f-4b67-428d-b82d-1c27f666cbdf	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.426+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2afd1be2-504f-4de9-a6af-ff6d0dbe61d7	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.727+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5848b8bc-3a2d-4a04-b5c9-5882e0e9228a	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.826+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c73901a8-70cc-4b42-bf91-69857a21b18f	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.626+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
af5aeca8-97a3-4012-96d2-c19eeb7aaabe	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.732+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ac252e11-0800-4128-978f-a3182efaeed3	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.93+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
f30701e4-cd16-44a4-9e49-262ca185017a	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.036+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5344833c-c188-49f3-ab45-42f0163e72a9	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.227+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
86be4c6d-40c3-49fb-82e1-1cd32a48364e	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.728+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
19f30238-6b8c-47a3-a0fc-b8009e701f17	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.027+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
53c890d4-d215-49f4-89dc-796024c5cf55	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.528+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
97a69022-ec5f-43d8-8681-ed1d54da3825	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.699+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6c4f9e87-86e5-4efa-8df2-a4d852b88f38	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:07.994+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
327fb23e-a479-47f8-92a3-b2c46cd3ae0b	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.125+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
50caea2a-37b7-40df-a258-65d682acb985	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:34.929+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6750814a-c0c6-40e7-ab46-09283e7559c6	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:37.482+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
58dbbb19-5a7e-44e8-a1e6-7ef7615deb62	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.733+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4f98a6a2-b301-4b17-82a1-d67d4ddd1784	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.935+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
11c18b8c-5248-47e0-87bc-d5777a96c00b	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.229+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
cd39bee9-7b7a-49ed-8bff-4eabf3eb30e7	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.635+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5c6317ae-f52a-4236-a0e7-5ef7c7f603f5	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.83+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7cbd60e4-762e-43b9-8e48-e5f047887c92	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.834+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7af88867-4bbc-4023-9f7d-c48c15e82487	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:10.232+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
502cd610-c464-477d-8be1-09cd694b035a	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.227+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
101be785-70e4-4041-87ea-1fba4f98e0ab	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.827+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
fbb9224b-4483-45c3-823d-4fb54f2f0355	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:36.611+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
a3f243c5-a39e-4671-9f70-f0578fb1263e	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:52.936+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
7feb6a45-3ae1-4628-8db8-eb46d14d5d33	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.232+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
219b5570-f642-45fe-8b86-cb676d282085	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.828+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
56b01916-d165-4a9e-a532-4147543e96e1	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:53.929+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3e7db175-453e-49bd-86b6-1d443875f406	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.531+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
96c83e39-0403-4dfa-9060-bb8c27edaf8a	Jarardh Jacob  C	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:30:54.894+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5604845e-5110-4a07-864f-57e949b67d2e	Jarardh Jacob  C	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:18.847+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
20dce4fa-a9cd-47dd-9bca-553431d62f16	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.433+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
16600c66-82b5-466c-87a4-ffc2372017aa	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:34.727+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
aa18a4c5-0bf0-4c4c-9f57-742df3dc1396	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:34.927+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
4a2177ee-3762-445f-ab18-1c800a72fcb8	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.824+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
41ba33b3-fa10-413c-92cd-b0cc9ce70eae	Jarardh Jacob  C	Test Book	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 07:31:35.996+00	c7e9f48e-682b-46d1-9f28-63d302ba74fb	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
e491e879-8934-43fe-944d-22cf172e725a	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:13:23.969+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
95fc9005-86f0-4856-b5a1-f5e54fdeb539	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:06.725+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d59efd76-3bd5-4c40-8ddf-394d3e19ec9b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:06.788+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
106d23af-e146-43a3-830e-f2696510d211	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:06.965+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
c4883f68-4636-41e3-80b7-0961d4d8601f	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:07.08+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
671cc96c-e420-4740-a287-3f2a030bb9bd	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:07.252+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b362d9e9-75d9-4856-b02a-a94dc04587eb	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:07.367+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
45e1ce57-e272-4dbb-9bce-63fbf345cc21	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:07.548+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ce046b99-0627-4dab-94ce-11d5e6b2f089	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:07.702+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e754e06d-f3d9-48ea-866b-5c5e6ba122e9	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:07.845+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
611f0948-837a-45e0-8cf2-fc0ba95465ce	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:08.038+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
18d3121e-1517-4cb7-995e-a8db2f45464b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:08.169+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
317c2481-e07b-427e-a024-4c64c8212f05	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:08.312+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
4374d439-52e0-49ee-92aa-f14b55d094e2	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:08.462+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
7023a1ee-25a0-42b1-9ddb-30164f2e173a	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:08.614+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
0d3c95e5-64e4-4527-87d2-3e209ef6f1fd	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:08.782+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
5f373a9d-1c51-4d6c-a3dd-56051f9e1604	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:08.942+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
765647f8-8699-49e8-9f2e-881ff0855480	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:09.073+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d64e4175-5039-43ef-9b88-f612ade4f261	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:09.272+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e33b9a0d-6068-4f4e-bc3d-e250e8508f26	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:09.408+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
5267b53e-b681-4d8d-a9b1-2d5879fd1a96	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:09.523+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e35f7c68-777f-489d-807a-5bafa3082236	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:09.753+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
dab210e8-598b-4061-8dcf-500b612366cf	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:10.558+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a0c61559-e963-437d-88a1-e9a2af105705	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:10.718+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
cc49ec6d-79e8-461b-b2b0-a240f248dbec	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:10.882+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
52c3f673-e4e0-4a5d-a184-69051c6d87e1	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:11.123+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
72548736-81d5-486c-8a3f-827673a5bc11	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:13.003+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b880985e-1de6-41ec-adf1-66856906f4b3	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:13.297+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
62734953-7a12-4493-8041-1ebf13fa4fbe	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:13.43+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
cb532d1c-36c6-4706-861d-a6571d187f21	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:13.57+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
3be126da-ad4e-4516-8fca-53250caa59ad	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:13.592+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
21fd4de4-463a-4393-91e6-75b8e2cfbed2	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:14.267+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
2fb33f64-ac16-426c-bfe1-c80872b2aaa2	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:14.576+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
553eb892-f1d8-4224-9828-3f39ced24589	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:14.932+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
828472ef-fa88-48dd-a153-36fb9cb5bd63	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:15.465+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
9e16d98f-b131-4d2b-a207-5739bddf553c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:17.499+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b81f3a17-5b3d-42cb-b2a0-66b33270c751	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:17.662+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
11fcefdc-2586-49b7-80bd-b751ecb0e94c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:17.836+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
12bd6341-c682-450c-a5a1-d12228809918	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:17.982+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
55ab5a70-d30f-46aa-99f1-0967388cf871	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:20.239+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
fed3417e-71d6-4a81-bb00-76a58c75894f	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.028+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
2cd74cb8-ad7c-407d-83f4-eadd37297d78	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.632+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
f8b0b361-076b-41cb-b01f-0e449c9f5996	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.738+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
fcbe22c1-a4a5-4346-8cb8-836d94aed802	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.134+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
114606bf-a4d1-4089-9764-c993dfe70cfd	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.229+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
c1f44c84-2900-4ad5-80ba-05314f3ddefa	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.727+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
04fe0be8-3bb2-44b1-ad4a-a87ab01919f6	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.935+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
3b065bcb-b818-4015-be83-ad48a0a8e349	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.129+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
11439194-98a7-40c7-a855-ec3436124aae	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.23+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
57e7c8af-c039-4f54-9c17-a4ef924a2f54	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.733+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b5387b5d-94b0-4139-a827-4445d6c20a88	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.331+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
785e59c2-2930-4889-8ed0-5a7769a33c59	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.937+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
1ac15357-28b9-4a21-a362-ebe5b0e38695	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.233+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e1d7778b-bf75-4993-8c99-e966ba57a239	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.333+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
386d0635-8fe8-4ae8-ab47-d7448868f75e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.838+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
af365c94-fb56-4690-b6f1-0e8c36f9b03e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.928+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
1c65ba92-22d1-428f-b564-33c485978ee6	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.132+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
2bd61712-06b6-45af-a80c-50b9af4487a7	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.635+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d8e01d7d-38cc-414a-8827-5e91cf36bc51	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.135+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d62ab08c-37b3-484d-9ba3-dd586eb0c921	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.435+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
5e7171dc-1759-41ab-bc90-58f3c258fec0	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.535+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
95336c4a-0ea9-4b34-a1a3-d3239a9342c9	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:13.141+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
730dc8f3-8fd5-41c6-b9c2-c1d2ed3fcaed	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:13.928+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
1a4d5cde-fa76-4ff1-921f-3c89daa9a314	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:13.931+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ab7cddd2-fd72-4d8e-8516-cda827cd25cc	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:14.096+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
97672834-4c60-4dfc-a79c-7b65e1360e86	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:14.433+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b1c2c0f8-7070-49f9-a2f4-dc48fae52f94	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:14.761+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
7d7184d6-c8e5-4f9b-b765-2ab57c033a20	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:15.113+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
eda92244-bea4-4a61-866f-1800193df301	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:15.273+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
04c86a8f-4a51-468d-bca5-c1cbe1d0866b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:15.636+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e6c024e8-d0b2-4172-bf25-93765ae9df28	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:15.811+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
27c65a4b-8608-461b-a206-4924a4d61dbf	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:16.97+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
52d42929-1e4c-400b-afb9-42f5f57b810d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:17.333+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
9fd5ba8a-b23e-423a-bd8b-ff9c0e77cf0b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:18.141+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e66eb852-9d9a-4f7a-9b53-73a924e58aa8	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:20.237+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8c351294-0feb-450f-9b58-b466b173cf4d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:20.532+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
907154f8-57e8-45b5-98b2-393a8b56f8ca	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:20.628+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b67fd9b7-57ee-40a0-9247-e11f627542d9	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:20.933+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
1ff74750-13d3-4147-ad11-82e7c1b042f5	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:20.94+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
0d07667d-80c6-424c-969f-451443daaa2d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.029+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
4b8cee5b-8d93-4931-bf1d-2eb0f500da55	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.137+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
91fdf563-b89f-4c7f-98ac-abf237022aa4	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.135+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
eac4e334-c516-4ea2-8ea5-df0c774bd410	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.03+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
bbb410a8-2990-4034-9f2f-54318c97d96b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:20.832+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
24e03a6b-01cf-4a87-b814-297dc201b45c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.533+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a21031e5-cd06-4acb-bef1-4e264a4506fb	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.631+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d3873baf-b662-4b72-862c-ade4ed232dfc	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.235+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8633809b-06a4-4ae2-9b04-f8149606c4b7	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.728+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
4eeaece0-4373-47bb-b1a3-657eb7548977	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.434+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ed3efb54-425b-4db7-9633-4a7a051e2bf3	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.437+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
40175e8e-57fb-4b2b-93d2-6b846312bd09	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.834+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a30153fe-fb99-472d-8e48-e9b4c62a882f	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.832+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
596c2087-d689-48f8-ae19-ef35a486382b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.737+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b6d62515-680e-4fff-bad1-4735ab06a5ca	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:21.933+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
deb8cd39-443c-42cc-b67c-b83c19ca1949	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.136+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
3217c822-acfd-4d05-b864-cd845e5c94ea	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.138+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
556e33bd-6d10-4d48-a5a0-1a1111e10f63	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.133+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
6c6dd892-2c7c-45b8-8331-1f5e656c2595	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.336+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b8d73f3b-017e-47b8-9a1c-bf039de808c0	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.631+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
5c378ee6-c9ab-4651-a869-532810fdf94f	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.936+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
aeb8a448-0666-4d3f-a765-999d27df7b01	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.235+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
785223ae-2fa0-4027-8683-4375fa6d9c75	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.53+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
9a7046f3-3826-416f-928c-2d2329aebdc5	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.735+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ab2b05b0-5539-4d2c-b078-fdaa403ebf4f	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.329+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
2f6abba6-bbf8-4d27-96fa-fa3c099a557e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.543+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
12220b4f-c560-4f5a-961c-c6f582168db7	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.43+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
be17ef94-2f02-4f74-a850-0b19407f918b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.829+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
5bb900d1-5063-4eb4-950d-d789ef4d83a7	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.133+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
72770bd5-9fec-4511-b6e9-caffc08748b4	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.23+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
2c67cfb5-d6e4-47d7-af26-8e1b55a1baee	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.433+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ab08cac5-ce2b-4ff3-8bd1-91bc893d31fc	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.637+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a7834428-200a-4a9f-b389-fe41914ca7b7	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.829+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
46fda546-4b52-4ad6-ad0e-6e23f1017bc3	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.33+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
320fc9b2-42c7-4598-a5c8-b0d2d824ed36	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.933+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
37eb6fee-9a42-4a10-8eae-a1834b00113d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.739+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8d97f4ec-4574-4827-8a1b-4c9fb41db49b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.031+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
904d6dad-74d9-49cb-b152-e508070d9d02	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.095+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a1897093-9f29-409e-9f51-cb640394880d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.135+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a4113fe8-d895-468f-89bf-d37069400737	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.398+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d26b6102-24eb-4940-8b76-74ebc8c58c09	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:46.661+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
7d6158aa-9ebb-4297-abf1-73a0c631ce08	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:47.414+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
b63e34ac-d3cc-48b8-b41d-bc059c437363	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:47.873+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
1f0aed37-0f20-4d41-ae4d-e65ad0b7299f	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:49.613+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
cdfcd1ef-02c4-4f5e-b006-4018a98adeeb	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.831+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
798edba8-f70c-474c-91c7-932d1d6beb78	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.128+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8105632f-7329-468a-9ba6-8cfd6a913066	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.333+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
465c60d4-0511-46e9-9576-125ca2efdd97	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.439+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
24c2eedd-f1d4-413b-84e9-1445a92bc9b3	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.539+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
da284337-c5ea-4e36-899f-d0eb070f7ba7	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.13+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
5781be8e-0dde-4594-bdd2-43eb1a326404	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.831+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
1d6bc8d3-c18e-4b95-a54c-0f74bf8ae057	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.032+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d49ba9f6-9da6-4e92-a95d-12dae4092a4b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.732+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a0b6d1ed-a390-46a1-a164-18606e4dc7eb	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.027+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8fb2ca58-7ec0-4a94-bc08-1a5480ce3043	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.333+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
1db7bde3-09eb-45df-9f31-c9fd7a3ad41a	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.933+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
f23615f5-c53f-4195-ae63-dee62c80483e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.229+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d4ef1581-8168-40f9-bc23-2d9a3d61e17c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.732+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d23cf207-0a6a-480b-8116-ee36b1821e6e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.435+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e7d5bc5b-cf18-4b3a-a621-f6ef0fc34a6c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.533+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b98a0661-bf7f-4ed2-91bd-c903256cb609	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.629+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ecd9929a-ea57-4be9-a068-3692477b863c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.238+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
fccf4ff4-658c-402e-8bf5-4bd4e111f131	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.739+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
bf255839-32ce-43c8-9480-3252a9189590	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.031+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
63d7a225-3dd7-483d-a2f2-fc91946b054e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.133+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ddadb86e-44f7-4614-88cd-0490d2b90000	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:47.11+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
af3d3a87-01c6-41de-9512-c715a1658661	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:49.158+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
854f5779-360a-4524-b0f5-4ef445172029	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.832+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8d2b0efd-9bbe-44ad-8908-9c185dcddcf4	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.238+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
74393eea-8c45-40ea-bbc4-df2072ffe780	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.139+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
973c4dea-1884-4020-9b18-5e0acb93eb96	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.33+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
2d923897-3385-46f2-8051-c1445eef3f8e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.433+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
1a901c7b-6079-4a93-95ac-da7af81ff597	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.731+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ada15893-eb22-4806-bb8c-9bab9f460fb3	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.131+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ae68efc2-685a-4ee7-bd8b-a2ad78a23db9	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.135+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a8e66080-4545-4ab8-96a0-a5efc5774a2a	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.328+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
fb713568-b4d0-4f68-b6cf-f7277832740d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.736+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
64030034-593c-4c21-81cc-613da58b965b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.431+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d861e9e8-995d-4ddf-a35b-63e3fba14c34	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.833+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
3c421a60-f423-469d-9071-abb277187a81	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.028+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
dea338a0-215f-4612-9abf-08d9ee253255	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.14+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
51584637-d57c-4441-a83e-961974e5bdf5	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.527+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
c5d52a16-1905-4a4b-8bf3-c11f29059458	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.133+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
75eee456-fe69-4f1f-a652-e26f718e9cd7	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.437+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
faf3fa12-d010-45e5-8088-4f959f919dc3	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.74+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
5037b379-2208-4c67-966d-bbcd0ccda906	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.132+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
baf069ae-b84b-4011-88fe-fd16347ab15b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.228+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
bc8c9191-e03b-4615-a995-cb3a80ec180d	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:46.52+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
8a26d750-24dd-417b-a7e1-9d3fa82a8386	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:46.797+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
4814e8db-b90b-4cea-ad30-e348d3b47c7b	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:47.554+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
9a90546b-157c-4c3a-a329-94351ae03859	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:48.702+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
fc8679c4-3117-417e-bf0f-dc4e5788e117	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:49.305+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
f0057405-dddf-4fff-a30e-cb50ad7157e9	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.833+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
873ed9c0-8031-4b4e-9529-a652facc05da	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:22.029+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
71e84a05-cc3a-4c9d-80ce-44cc9ad4a55e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.037+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
23c45aa4-cc36-496a-9651-e9bc75985da4	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.234+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
7c243f94-a184-4b70-803d-bbce3906e7b6	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.436+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
72a3491e-998f-42d5-a0d9-5ad3f70ac434	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.54+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
05ee161b-af7e-4ffd-8a92-f4cffdc8a728	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.636+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
051ad568-8e1e-41c0-a8dc-702ff2309ced	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.842+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e8b15bd0-c608-49ad-b478-5dc7cd4e856d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.129+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
00556951-7465-431c-8c63-d4e2ee9038d3	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.337+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8e4327cc-5a70-49fd-8cde-4edc8f8c27e8	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.134+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
460cc320-81a7-4118-989a-ca9977379bfa	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.734+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
862c6634-7056-4a42-8224-815293ff69e2	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.931+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
bd7e475a-10a7-4bd9-8634-5a20d217551d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.232+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
295ca25d-80b9-4570-afa4-07dcc95ef79e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.636+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
511e2ed9-3149-4559-98b9-a7d68e76e946	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.932+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ddb75aac-a58d-42e9-9252-fe6698b6cd44	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.229+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8a809a6f-e6c6-42f9-a6b1-242c8afae235	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.534+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
0217a59b-c40a-4a64-9d2f-46352c1deb08	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.237+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
803edbcb-f8e6-4230-a6a2-4384033055f1	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.531+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
003ff596-859a-44d5-a0b4-12c465574b77	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.03+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
302d9324-a175-4a70-83f4-bbeeb41374a1	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.127+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
1719e100-0d6d-49ea-b7d6-90efa701df0c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.13+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
b151a0c7-e1e8-43ce-acdb-bd1690d799d2	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:46.914+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
7029cfe5-6700-4a96-ab63-597a55f552f6	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:47.3+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
c973e848-d2e5-4d2c-9cec-276f9a5823f3	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:48.04+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
26e8d31a-c678-4d53-b12d-7b6e6bcc8f9b	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:48.707+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
dc75e47d-5691-4831-957a-c4a5d7e7b3bc	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:48.982+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
9fa3cd72-9150-4bec-9c53-7c729d9556eb	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.334+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e417a2be-6b4a-469a-b4c1-a261b5d56799	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.527+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
7e0a516f-2578-4de3-abac-bf0ce064ea11	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.628+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e570312c-34df-45ad-91e5-120874218bc0	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:23.84+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
469d1f73-86cb-407a-bd1e-ba3e82b78e70	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.03+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
59f27742-f762-4d0f-b336-427c9b5c3705	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.128+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
10c277bc-522e-43f9-861d-ea1f3ea0ca70	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.234+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
9c6f43fc-94eb-4122-b649-e4b797fb3cbe	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.329+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
cd16082f-af8b-4b8e-88b0-59d708c60c6d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.33+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
7abb0de0-748c-4c86-9986-73d5171fba6f	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.728+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
39018f5b-b041-4ebe-a61b-46aa3cf42a38	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.83+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
72d33387-ee03-4549-bbfc-ced467ad259f	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.933+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
f19dd5fd-aa13-4e17-b886-a5b06e19b423	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.935+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
f12288ec-a9dc-4ab3-b77a-073bc434c290	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.231+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
dce08e79-2539-465e-8e73-e9f9a8106ab1	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.427+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
0f6cc5a1-a871-405a-bb4a-28c37b16a54b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.429+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ba7af0f9-675a-4b07-80cc-c60ad462c8ce	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.727+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
0faf6f11-6f81-4cef-a528-fb6b0f74cf23	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.032+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
5aba528a-8f89-437f-a04c-0b10e443e8fc	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.03+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
145ad78c-2928-4be2-a7e4-f33e2c3c7148	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.141+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
43ae6727-df20-43c4-93d2-055345d7f734	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:26.53+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
f657a519-4e77-460a-b634-b0146a3861c6	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.533+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
4131a5c0-ad40-4d24-af97-4e7b98af7a7c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.134+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
6fb45cff-f9f6-4208-9ce6-def1ecc54e48	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.533+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a26b8564-5f86-4841-9be3-44f1d1c3f6a8	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.536+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8c769997-139a-45b4-981e-329adf9ecf20	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.928+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
3c4613f9-b3f0-4553-a5f0-15373629a82e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.536+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8c7ff27c-f8a0-413a-a433-1e8874a0b4e8	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.735+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ccbdbf4a-4bca-4765-9413-d9e0193c61d0	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.736+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
fc903795-5839-4290-9438-78d654818890	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.029+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ab7305c4-ffcc-4c96-b6a6-1d5799be69a0	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.129+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d595641f-5b14-4920-9b47-4f996a20b178	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.131+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
03f64bca-3f27-405a-8753-889ccaccd3f5	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.135+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
479df6ff-7b79-45c3-beac-2de6da72744d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.428+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
d13ca233-4765-49ce-b6cd-3bb386bf2a82	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:46.631+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
072fab1d-8d14-441a-8160-dfc8e742a9c8	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:48.705+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
2febc21e-6f25-4c36-b9f1-f599e2c5cf31	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:48.727+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
d34ec63a-7d21-4f1b-8471-95973a740a7b	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.133+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
59d024a8-6a8c-444e-86d6-af65bf1b5a7c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:24.932+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
6e6ff05f-6881-4d86-aa52-04393705b75e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.03+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a56bc569-844f-4dcb-98ae-17fab7cf3334	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.234+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
19470a66-a97a-45b3-a1ca-b9661256349d	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:25.331+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
efee3a77-8522-4734-b3c0-d1cb4856543e	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.029+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
f25a5b1b-b765-493d-bf4c-adb2f3d81af6	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.53+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
27c7c118-24c6-4338-ad81-7edabc74e681	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:27.638+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
226fc2b3-1b67-4ac9-9238-b88e8c57ee97	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.134+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
ef4a6a1a-aeec-4141-8efe-75164580a1a9	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:28.438+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
e8389213-bb23-4f92-a041-14e433982890	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.329+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
763c6fe5-33ff-4a1c-bd55-0b9304315ae9	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.033+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
8583c7a3-6ace-4104-97cc-899035b9a2d0	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.134+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
997c0642-b7f9-4bd9-93e5-f1df8ae9ee20	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.23+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
9c547c48-9079-4189-a24c-019b7c195eb4	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:49.845+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
f8d2923f-1b3f-487b-bbbe-63b9808cdcea	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.327+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
f832ac83-5627-4f86-9d4a-bb42f326e1d7	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:29.631+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
950821e6-e9c1-4155-a25e-3b667c74ef55	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.093+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
2fdfb9a5-865c-4e34-988f-01a3fb8313c8	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.132+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
a79b01cc-9127-4852-b4f0-c5da2e52122c	Kevin Jo	Test	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:30.233+00	515cc9dd-aa4e-478e-b038-6c5576c2e538	f8433f32-428c-4011-8cd0-64ce50fca8f9
6f6d4344-9edb-4843-9dc3-1708330a20ee	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:46.805+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
c932f4e0-eaca-4a16-bc44-aaa7559b333c	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:47.696+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
04534fb9-9925-40d2-878b-9aba8cf599a2	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:48.935+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
c16af5b4-9448-4b03-948c-db63312ccfc1	Kevin Jo	Test Book 1	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:15:49.457+00	2c9fbe27-d475-450d-9b22-0cb0800eb20e	f8433f32-428c-4011-8cd0-64ce50fca8f9
983e8f67-7534-43ef-936c-e85de557fe99	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:35.797+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
09ca809c-e9fc-4a4b-8734-1224e5340551	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:35.813+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
baea0f71-173a-46eb-8a9b-7ef931584dbb	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:35.959+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
3cc5d769-ed92-4804-b3c2-0766ffdd55b3	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:35.972+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
624c904a-8ae8-460b-bef7-64ebfa4bc839	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:36.118+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
2c945270-155d-4b6d-9a9e-ee4883620835	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:36.232+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
3a74cea3-2a7f-4d50-8a79-bef0ffcd21b5	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:36.39+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
35b1ccbd-6fb0-45e3-9347-715fc1f839c5	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:36.549+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
1d89ddbc-69a3-4d23-8410-fb8a68093956	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:36.721+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
6bc72b64-ee15-47a5-a760-a492813fda42	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:36.93+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
a013c9d7-100f-46da-833f-177f8e69c3c2	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:37.117+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
42c56bae-a80c-426c-b385-7094e15a17fb	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:37.218+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
d7286e5c-252d-41ba-8380-1fdbed2c2e0d	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:37.391+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
106c017a-3482-4fc4-9975-dfc4d8c1345a	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:37.754+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
7e24658c-6752-4aef-bc9b-2d4f1707a1ac	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:37.992+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
8b8fc786-a9dd-4204-a8d6-08bea0e74d26	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:38.017+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
f02ed804-21bd-495b-a723-305279c05b80	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.032+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
337ea55c-92b5-4e95-b13a-24bda68be640	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.23+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
b7133083-a2b1-4fc7-b0b8-e2645a18ba45	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.236+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
95fee515-f409-4265-a15b-0532cd5d216d	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.238+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
a737022c-551e-48aa-b59c-47282cf60360	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.239+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
50f9b384-46c2-4028-8e62-3655714e2882	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.034+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
cccc9522-59c6-4d51-9dd5-a3e2ad6e1287	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.128+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
01d8bd54-6d10-4eca-b427-2987bdbb4fb1	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.032+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
61f4300e-8c79-4404-ad48-330268a25b0b	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.429+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
98f7832c-7df5-4c18-8f4b-a73a0b51054f	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.53+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
c95f5e11-289e-4cf8-8bc5-ab40e3c36ada	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.533+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
572d0ae6-0da8-4567-9408-1ab92bbaf989	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.534+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
f070ba14-944d-429c-957f-fa3849ac0945	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.573+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
7401f6eb-9ff7-41b1-b11f-09e29f6a853a	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.588+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
aa49a82a-210b-4649-80fd-f6a06b6a3ca3	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.591+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
60bff671-e0ca-4411-872e-fee49fce29e3	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.66+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
d0f24737-d901-4ba9-b970-be90b5ebf72e	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.699+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
3fddaf50-6423-47da-9e40-fb1e4dc21bc6	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.731+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
90c18072-b373-40e6-a288-35b9dbecff5c	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.833+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
85084477-cb92-4245-afcb-4dd2be4bef74	Kevin Jo	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-09 08:17:40.901+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	f8433f32-428c-4011-8cd0-64ce50fca8f9
fad8cec3-3600-479e-ba89-8140b490997b	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:29.806+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
add99dfc-fa17-4713-a6c8-055683b22558	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:29.859+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
91e76224-9bde-4915-a58f-3f47b9fab316	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:30.264+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
440bcef6-5754-41c9-8f32-76b11a7d118b	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:30.753+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
de0c490f-8982-4e05-8c6a-2eb317fce6b1	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:31.122+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
eb482b0f-f95d-4641-9c0e-398ae3307dbe	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:31.46+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
6f4bc2f8-622f-47a3-996b-ddc6ea37e52f	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:31.892+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
38ee856e-25f8-4690-aee1-eb0b48a9448e	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:32.316+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
819307ae-9387-43d9-9f5d-71117c10002b	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:33.163+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
c99c3188-0ff7-46d1-b8e0-bf54ffa95c03	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:33.896+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
ae84c73b-53a4-41e2-9a4b-589e813e763f	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:35.863+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
44ba6bc2-2f5c-4f53-a2f3-55dc54e223a8	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:36.333+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
5d166121-090a-48cc-881f-fdc0d5a97705	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:36.571+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
097884fa-f09f-4786-bc8b-600da22aab3f	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:36.709+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
bbeefee9-e2d6-47b5-b81c-0527d47ad565	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:36.928+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
3465459f-2fc1-4d7d-853f-6ab4c71b6ee1	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:37.594+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
8eb1a6a7-53ea-43e4-828b-d526a40035b3	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:37.758+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
845967fb-4d50-4053-a88c-b339a77d2aeb	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:37.958+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
7933ebdb-ab8e-4e14-a63b-0708a3119c74	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:38.125+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
e9cd749e-36d0-4147-8600-3e641a3e51e9	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:38.34+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
e3e5dca6-215b-48b2-95fc-ccf32d1d44cf	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:39.303+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
a3ed74a9-21b5-44a6-94af-ea119c794f53	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:39.463+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
7663640d-35f4-49e7-98de-1e7e624a70e3	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:39.649+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
4c7b3943-4f2a-431d-a9d2-ebec7c1cd156	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:40.024+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
28bab725-f6a7-4b33-b91d-4a1268bdeaa6	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:40.217+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
d965f571-20c8-4cd3-8a21-9cd5b6b424b2	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:40.272+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
da6220b8-7427-4319-95a9-a91d5be6e5da	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:40.363+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
3d4dfa3a-92bc-452c-93c6-472717435398	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:40.821+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
4674a2cc-8fed-42ec-9b40-af8b7cc2166f	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:40.969+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
9ec43fa7-3b89-49a6-963c-7fcffa88bde3	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:41.077+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
13cd3a44-f328-49cc-941f-0e13085d019a	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:41.131+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
90710aa0-e29e-47c9-b6d2-dcf1c1a28c4c	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:41.238+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
99b3b1d0-faa2-4552-90e5-7e19affb186b	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:41.373+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
8240c90a-13aa-4b8b-8d07-c5ea1245a2ca	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:41.908+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
c5576558-bcca-4342-8bd6-a3df1ac121ed	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:41.547+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
2839ed21-2463-488b-a36b-8be76cb4f8fc	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:41.838+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
33185fe7-4913-469d-9a00-843cf25d663c	Test user	A Text Book of AGRONOMY	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 03:23:42.18+00	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	cdff310d-1cbf-4803-8c8b-b93195ac374f
89d3404d-be52-447d-a8d3-0718582c9562	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:39.714+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
54076a43-88b0-4a89-81f3-2eee44e31a97	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:39.726+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
f9e30797-8527-4f20-a918-ee30f11c0b2e	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:39.823+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
3906eb60-68fa-495a-a9d5-899a3dd53e07	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:39.908+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
2351fa58-d957-4e31-ae52-03858196ac91	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:40.01+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
bc5f2767-7d39-4fd4-8dc1-567ef0846958	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:40.178+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
d0b55e88-d102-4105-aafa-5245fffe14a6	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:40.283+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
853207a6-1b9a-4d83-96e2-e826441976de	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:40.438+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
472317f9-aacf-4cc5-b719-aae04cf36953	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:40.578+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
39684795-360e-4f5a-890c-ef3125d11512	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:40.733+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
4ae273d5-6cab-4c5b-ad86-e6bafdaab027	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:40.991+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
5343a929-e203-40dd-83eb-2cc83649705c	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:41.045+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
3966454e-d56f-42bf-88c6-4098493d1652	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:41.196+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
e072281d-9de5-4934-a02d-dd3ae8cc54a9	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:41.378+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
9b7e82b6-9cf5-4406-b3bb-5e1a2d3aff1a	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:41.549+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
f4515e68-ec74-41b8-8afb-c958d1cde324	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:41.778+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
c2dcc991-f6d1-4f94-b161-db8b6eed8d44	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:41.879+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
d5f43cd4-ebba-47b0-b32a-ed81ed76e1b3	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:42.027+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
e7dd9b5d-5593-4683-b414-2a5e660cff32	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:42.204+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
6735ffc1-f5fc-4a13-9dba-9ad7cdbfa6bc	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:42.405+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
487cfcaa-dae4-4884-b22f-376e2d761cc8	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:42.525+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
7681a886-b91b-4f68-b87d-3fdf7b7111f6	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:42.665+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
0658c929-252e-4832-ae16-4dd9f3013264	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:42.854+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
d376a68e-0c9e-4d49-9513-45fcf1f9accf	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:43.032+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
8fb22fe2-bf6f-47cc-b272-6e3ce4e36c00	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:43.196+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
dac78adf-10b4-428a-84df-ec980f7ab72c	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:43.371+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
36a7825b-0f0a-499b-8075-96bf81780bc3	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:43.518+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
66d349e4-28b4-4ee0-897a-34fece2ed8e9	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:43.676+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
b3369649-f5a9-419e-8b9a-f48dde2d3a44	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:44.041+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
70b85030-c2d5-4743-a8bb-469be14ad700	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:44.112+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
7c69f08c-09b7-41e8-bc94-3546a81d5e65	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:44.442+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
34586f4e-7b7d-468b-9e72-650f46c5be99	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:44.786+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
d6eb0983-c277-4504-bd1e-57cf55818ae4	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:45.396+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
2eab66cd-ea0f-434b-b365-a3fcf3cdf12d	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:45.683+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
0564442c-60d0-4ca0-aad4-a0a4106eb5b8	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:45.951+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
72894691-c101-476a-90e4-6670ab6b357f	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:46.284+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
9340fa8a-2904-4b51-a237-a84753b42e01	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:46.946+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
2717566a-2e79-4bc5-867d-aa5bee9a269e	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:44.278+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
d7001101-d167-4c31-aea3-9aabcd60bf58	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:44.492+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
cb1dabe4-68d5-4a31-933f-6677df371563	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:45.831+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
ed6b1467-e60b-40ae-8dee-c73f2a5956b3	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:46.119+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
33b35c7f-15fe-4279-8854-2320240118d8	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:46.784+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
6b4ecba0-5c8a-4eba-b40d-22c47bf77268	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:47.233+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
90a41883-6331-459b-8e63-24f48e4ccdcf	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:44.635+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
85f3b917-fccc-4775-ab8e-a21ad8cb808e	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:46.588+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
3d4700de-9e44-4a75-ae42-5a732dcd978f	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:45.243+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
d32eb17e-a5bf-48c2-9d64-c78cb988fa2b	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:46.437+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
623a895a-301f-48c9-b778-ac99ec03a637	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:47.091+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
3e4aed75-6a84-4091-a3ec-9c37c2293e4c	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:45.287+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
1e2cbdc3-34e3-453e-8b5c-b5fd8c1ea05f	Test user	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	::1	2026-02-10 04:36:45.43+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	cdff310d-1cbf-4803-8c8b-b93195ac374f
769d0998-dba4-4201-9d95-01bdc43c0e0f	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:24.088+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
9f69bb03-1152-4d07-b552-619b0e0f0531	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:24.937+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
dc33ba4d-7bad-4549-ad48-894844eb3efa	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:25.681+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1f1bc960-0587-46d8-9dec-cd39b12f9c78	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:26.086+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
2c9576ef-7b54-4ebd-9bd6-170668c59701	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:26.307+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
bbd4ad65-63e2-4231-b9df-09ec45681499	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:26.479+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
5733d436-df02-4261-8257-6a6e4ec3d96d	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:26.659+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
aa8d95d2-14e3-4503-b66f-f3c329c54ab9	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:26.817+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
db95b71e-8bcb-4d30-823c-2a271053bfc1	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:26.975+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
13e84b03-252c-4e54-9e75-f384a1a11c1f	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:27.196+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
0ac31bff-2039-46da-bcc1-68503840af11	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:29.988+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
82ea5594-3d3e-49ac-86f1-a9135129073b	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:30.025+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
3f4af357-95a6-4ec8-a343-9c91791eb279	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:30.129+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
148cfbb2-68a2-405a-add8-2ef206aa47b5	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:30.213+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
1f9f3030-9c71-408a-aea1-f28d9401d699	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:30.341+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
6761e6b4-95a6-419e-a228-21e9af275601	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:30.512+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d539cece-7106-4b77-8a47-fcb1decbb0ee	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:30.826+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
d657387e-a5a8-44e8-8b57-197994d4b24c	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:30.941+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
c469d2d1-7e56-48c6-b790-356f4c5c39c3	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:30.998+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
ac2fbb8c-00c2-44b0-9753-9c858f5cc6e4	Jarardh Jacob  C	Fundamentals of Extension Education (ICAR syllabus)	read	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	::1	2026-02-25 05:27:31.198+00	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb
\.


--
-- Data for Name: drm_devices; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.drm_devices (id, user_id, device_id, created_at) FROM stdin;
799	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	b6bc81d7-a98a-4403-aca7-01ca486badb1	2026-01-07 12:01:52.862
792	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	7a2151f3-2264-4314-a812-53ecb541892e	2026-01-08 04:01:43.963
805	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	29c68710-6916-48c6-868e-4b8ab7ed9f73	2026-01-08 07:26:10.771
\.


--
-- Data for Name: drm_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.drm_settings (id, copy_protection, watermarking, device_limit, screenshot_prevention, updated_at) FROM stdin;
1	t	t	2	t	2026-01-07 11:27:40.021+00
\.


--
-- Data for Name: ebook_ratings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ebook_ratings (id, user_id, ebook_id, rating, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: ebooks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ebooks (id, title, author, description, pages, price, sales, status, file_url, created_at, tags, summary, embedding, cover_url, user_id, category_id, rating, reviews) FROM stdin;
c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	A Text Book of AGRONOMY	B. Chandrasekaran, K. Annadurai	Agronomy is a vital science that plays a key role in feeding the world and forms the backbone of agricultural sciences. It focuses on efficient management of soil and water to achieve the maximum production potential of high-yielding varieties, especially during the Green Revolution. In the face of growing population, declining land, and limited water resources, agronomy provides scientific and sustainable solutions to ensure long-term food security. This textbook offers a simple and comprehensive overview of agronomy, covering all major topics required for undergraduate students, and serves as a valuable reference for both students and teachers.	856	200	0	Published	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/ebooks/1767844540970-A%20TEXTBOOK%20OF%20AGRONOMY.pdf	2026-01-08 03:55:45.21+00	\N	\N	\N	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/covers/1767844543485-A%20T%20EXTBOOK%20OF%20AGRONOMY.png	\N	8342614b-05fa-4d9a-b09a-e09e9d1c9557	0.00	0
14af9fde-cd3b-41ec-9c82-fb0ecdce7078	Fundamentals of Extension Education (ICAR syllabus)	agrigyan	A full set of lecture notes on the principles and practices of Extension Education, aligned with agriculture curricula and useful for ICAR/UG/PG study preparation.	0	0	0	Published	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/ebooks/1767779435962-Fundamentals-Of-Extension-Education.pdf	2026-01-07 09:50:38.711+00	\N	\N	\N	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/covers/1767779437749-Fundamentals%20Of%20Extension%20Education.png	\N	8342614b-05fa-4d9a-b09a-e09e9d1c9557	0.00	0
\.


--
-- Data for Name: exams; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.exams (id, folder_id, title, description, file_path, file_name, start_time, end_time, created_by, created_at, subject_id) FROM stdin;
\.


--
-- Data for Name: folders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.folders (id, name, created_at) FROM stdin;
\.


--
-- Data for Name: highlights; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.highlights (id, user_id, page, text, color, created_at, x, y, width, height, book_id) FROM stdin;
861f67a6-f1f5-4f84-9b18-8c3c77d31047	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:22:13.769287	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
5cc57a67-0f27-43fa-8553-49e78faba1b3	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:22:16.487235	-0.20407408255117912	-0.12610837939533304	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
b2016853-e34e-4330-908a-961adb456e07	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:25:03.817319	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
8d70ce99-d230-41ae-86d7-1d50283e13b3	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:07.888306	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
da225d4b-4cc9-426a-abb0-1f0cc020997f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:11.964242	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
ab97fb08-939f-4da5-be9a-fdffb9bb91ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:13.533899	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
5d1ea403-158d-4f39-8105-c49811abf383	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:13.636812	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
13a615f1-7c09-40cd-ad4a-c0837db27934	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:15.310983	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
96c94ac2-2d93-4bfc-b5ef-50a7b6c18a56	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:15.998932	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
efd34241-2d84-4a8d-9e7d-6e48f3b75e2f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:16.551809	0.09684028625488281	0.6193760212614814	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
9a7e9219-9c0f-4bcb-83ac-b50c29692ba4	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:16.933182	-0.20407408255117912	-0.12610837939533304	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
90230d60-629d-413f-b216-17360034e3d8	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:27.85979	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
33a42dbf-755a-49f8-9cdd-abb10c8d4e23	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:28.292226	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
ba27dbc1-ec64-45bd-85af-34c381f727de	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:28.73698	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
2e87a326-a9f0-4fe0-8550-692888f3a061	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:29.766223	0.344074065596969	0.5586206846440759	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
f797830b-cf1a-4717-8192-840a0a01b0c6	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:29.831506	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
2752fe07-eb50-49a4-aa91-59ca785e9e66	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:30.097391	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
6fc0538e-a3cf-41ad-83fa-7fdecbca54f3	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:26:30.177506	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
0ec5a715-09a1-433a-a90a-513a9d779499	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:20.754613	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
c1af1a9b-5be4-4958-8756-d8124a0d6acd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:22.046258	-0.20407408255117912	-0.059113300492610835	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
2e374d34-a1cd-42e4-b15b-947e471cba6c	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:23.429138	-0.20407408255117912	-0.059113300492610835	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
56ba9c58-abcf-4781-ac1b-52731db2d7d0	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:24.757229	-0.20407408255117912	-0.059113300492610835	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
6ddc590a-522e-44bd-b311-eefb4e065258	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:26.299525	-0.20407408255117912	-0.059113300492610835	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
ae0f1e87-e323-46ac-b87e-ca85d272a79b	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:27.780305	-0.20407408255117912	-0.059113300492610835	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
ba638313-716c-478d-8037-e655229e8dc5	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:37.208634	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
fe4ffebb-2243-453b-971e-b7ff4608e4ce	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:38.241009	-0.20407408255117912	-0.059113300492610835	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
d8b8dc7b-e197-47a1-baaa-9031e57ef125	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 09:41:39.73127	-0.20407408255117912	-0.059113300492610835	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
6ec6d471-887e-41eb-8f01-e20961a2ac67	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 10:16:06.292135	\N	\N	\N	\N	3ca5b016-7c38-4391-a929-c7351709cd60
6dea82bc-a613-4efd-83df-94bdae2ae05d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 10:16:42.845372	\N	\N	\N	\N	3ca5b016-7c38-4391-a929-c7351709cd60
315880ad-5388-4a88-8fcb-f38caa340ec8	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 10:17:07.69735	\N	\N	\N	\N	3ca5b016-7c38-4391-a929-c7351709cd60
ea518102-8f87-49d7-adc0-705b2aa230b8	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 10:17:16.545139	\N	\N	\N	\N	3ca5b016-7c38-4391-a929-c7351709cd60
fe238559-8cdb-4fb8-a2f4-b7febfd8341d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 10:17:17.55372	\N	\N	\N	\N	3ca5b016-7c38-4391-a929-c7351709cd60
8e3a0c0b-351e-426d-8d0e-7bebd579252f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-22 10:17:26.071991	\N	\N	\N	\N	3ca5b016-7c38-4391-a929-c7351709cd60
6d5d4e07-2f82-419c-8155-da52830d9e44	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-23 06:58:44.043856	0	0	0.0012345679380275584	0.0021893815649749807	3ca5b016-7c38-4391-a929-c7351709cd60
1848893e-0221-4a99-95f5-ae2f4e9a4a68	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-23 06:58:52.982031	-0.08549382951524523	-0.0722495894909688	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
58799d28-b455-40a2-9708-68bd32a986e1	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2		rgba(255,255,0,0.4)	2025-12-23 06:59:00.623459	0	0	0.0012345679380275584	0.0013947001810353172	3ca5b016-7c38-4391-a929-c7351709cd60
958f8783-22cc-4810-9db2-0bc5d65d5788	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-23 06:59:40.884776	0	0	0.0018518519070413377	0.0028860029720124743	3ca5b016-7c38-4391-a929-c7351709cd60
64e912c3-feee-470d-b9be-1dd7fe092173	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-23 06:59:46.721449	0	0	0.0018518519070413377	0.0028860029720124743	3ca5b016-7c38-4391-a929-c7351709cd60
1e945bb8-9d66-4c64-9231-2590d8b9e624	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-23 06:59:48.015797	-0.3888888888888889	-0.16594517695439326	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
0de6aaff-3ab1-45b5-ad5e-3893d34fe9c0	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-23 06:59:50.125961	0	0	0.0018518519070413377	0.0028860029720124743	3ca5b016-7c38-4391-a929-c7351709cd60
89a410c3-3db6-4006-a0fc-4873970b21e8	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-23 06:59:51.155354	0	0	0.0018518519070413377	0.0028860029720124743	3ca5b016-7c38-4391-a929-c7351709cd60
242d4944-80f0-45da-ba39-275c9db59bd3	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-23 06:59:51.374271	-0.3888888888888889	-0.16594517695439326	0	0	3ca5b016-7c38-4391-a929-c7351709cd60
0eedc113-ba4b-4d4e-b377-3d1642c8e18e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-23 06:59:53.183115	0	0	0.0018518519070413377	0.0028860029720124743	3ca5b016-7c38-4391-a929-c7351709cd60
a56a1703-00c7-4d5a-8ac9-6dff9d5accf6	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2		rgba(255,255,0,0.4)	2025-12-23 07:00:01.177949	0	0	0.0018518519070413377	0.0020898642211124815	3ca5b016-7c38-4391-a929-c7351709cd60
ac78271f-2f34-4219-af79-f48a12fef83f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2		rgba(255,255,0,0.4)	2025-12-23 07:00:03.897252	0	0	0.0018518519070413377	0.0020898642211124815	3ca5b016-7c38-4391-a929-c7351709cd60
38606e70-69e0-464c-a3f4-d561cdea355f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2		rgba(255,255,0,0.4)	2025-12-23 07:00:05.374453	0	0	0.0018518519070413377	0.0020898642211124815	3ca5b016-7c38-4391-a929-c7351709cd60
da83d37f-3f41-42cd-9468-7be0c71acf90	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-23 07:00:15.349909	0	0	0.0016460905840367448	0.002923976695328428	3ca5b016-7c38-4391-a929-c7351709cd60
95153421-44a7-4c4d-a38f-8f050df2e215	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-23 07:00:17.233875	0	0	0.0016460905840367448	0.002923976695328428	3ca5b016-7c38-4391-a929-c7351709cd60
e275a703-5fc1-43ea-99d0-7c5a3a960c2a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-23 07:00:17.898832	0	0	0.0016460905840367448	0.002923976695328428	3ca5b016-7c38-4391-a929-c7351709cd60
57a99f15-a479-41b0-aa73-9eb734c9f164	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-29 03:57:01.5976	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
f22fdf59-bcdc-4ac4-b937-234184676722	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-29 03:57:03.231466	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
2bfaa174-c202-44e8-86c6-2c2c41559c0c	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-29 03:57:05.813394	0.3644444359673394	0.24499178480827946	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
14f48f49-55ed-4638-8def-418cd73397b5	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-29 03:57:06.523495	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
738e69da-79ab-417d-92d7-9929ed3c4a98	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-29 03:57:06.590668	0	0	0.001481481503557276	0.0026272578388207846	3ca5b016-7c38-4391-a929-c7351709cd60
b04b8566-c9e5-46c3-b87b-ff15bfc3c7bc	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-30 09:20:17.028198	0	0	0.005333333412806193	0.0028170873166191643	6f9bd736-959f-4822-a6e0-404f358c277d
c543e6c9-08de-4daf-8917-1b1e73ec6bdf	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-30 09:20:22.677968	0	0	0.005333333412806193	0.0028170873166191643	6f9bd736-959f-4822-a6e0-404f358c277d
7a7e3744-86a5-4bff-82b8-df9222e5fc23	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-30 09:20:23.515826	0	0	0.005333333412806193	0.0028170873166191643	6f9bd736-959f-4822-a6e0-404f358c277d
cb1734dd-3f49-4539-ad06-682ab0dd1044	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1		rgba(255,255,0,0.4)	2025-12-30 09:20:24.543102	0	0	0.005333333412806193	0.0028170873166191643	6f9bd736-959f-4822-a6e0-404f358c277d
20daf466-d248-431d-95bd-70f390963025	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-30 09:21:39.259698	0.036655101069697625	0.06655259365994236	0.7277777777777777	0.07636887608069164	6f9bd736-959f-4822-a6e0-404f358c277d
3fa92875-d254-4618-824a-7b74d101c5c9	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-30 09:21:43.25688	0.04221065662525318	0.18472622038651612	0.525	0.3804034582132565	6f9bd736-959f-4822-a6e0-404f358c277d
016c2ce5-9a54-4aef-930d-18dd39b68dd1	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	3		rgba(255,255,0,0.4)	2025-12-30 09:21:44.897259	0	0	0.001481481503557276	0.0023054755386770287	6f9bd736-959f-4822-a6e0-404f358c277d
\.


--
-- Data for Name: integrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.integrations (id, name, status, config, updated_at) FROM stdin;
c3461248-2d29-4cda-a335-88492ec1f5cd	Stripe	disconnected	{}	2025-11-15 09:24:28.476+00
37a7dbed-3c7b-49ac-a72f-8b78197da215	Razorpay	disconnected	{}	2025-11-15 09:25:28.454+00
\.


--
-- Data for Name: interview_materials; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.interview_materials (id, title, category, description, file_url, file_type, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: job_requirements; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.job_requirements (id, job_id, requirement) FROM stdin;
\.


--
-- Data for Name: jobs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.jobs (id, title, company, location, type, level, salary, posted, description, requirements, created_at) FROM stdin;
\.


--
-- Data for Name: mock_answers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mock_answers (attempt_id, question_id, answer) FROM stdin;
\.


--
-- Data for Name: mock_attempts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mock_attempts (id, user_id, test_id, started_at, completed_at, status, score, time_spent, rank, completed_questions, expires_at, percentile) FROM stdin;
184	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	48	2026-02-09 03:33:05.117+00	2026-02-09 03:45:00.73+00	time_expired	0	0	\N	0	\N	\N
\.


--
-- Data for Name: mock_leaderboard; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mock_leaderboard (user_id, average_score, tests_taken, best_rank, updated_at) FROM stdin;
782c37df-f571-4390-bd69-fefdb0e13cf5	60	5	\N	2025-12-06 10:14:17.037211+00
aea41626-3127-4b2e-9103-d3f07855a3f3	0	1	\N	2025-12-08 09:01:02.161459+00
f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	100	1	\N	2025-12-16 04:27:57.423059+00
f9fce64d-faf4-4195-92eb-e40ed2253542	100	1	\N	2025-12-30 05:10:27.938243+00
7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	6	16	\N	2025-12-06 10:14:47.042078+00
\.


--
-- Data for Name: mock_test_questions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mock_test_questions (id, test_id, question, option_a, option_b, option_c, option_d, correct_option, explanation, option_e) FROM stdin;
85	48	Common bread wheat (2n = 42) is	Triploid	Diploid	Tetraploid	Hexaploid	Hexaploid	Common bread wheat (Triticum aestivum) with 2n = 42 chromosomes is a hexaploid, meaning it has six sets of chromosomes (6x), derived from the hybridization of ancestral diploid species, resulting in three genomes (AABBDD) where each set contains 7 chromosomes (6 sets x 7 chromosomes = 42 total).	\N
86	48	Tungro virus of rice is transmitted by	Green leaf hopper	Leaf roller	Gundhi bug	Stem borer	Green leaf hopper	Rice tungro virus (RTD) is transmitted by leafhoppers, primarily the efficient green leafhopper (Nephotettix virescens), which carries and spreads the two viruses (Rice Tungro Bacilliform Virus - RTBV and Rice Tungro Spherical Virus - RTSV) that cause the disease when they feed on infected rice plants and then move to healthy ones, leading to stunting, yellowing, and yield loss in South & Southeast Asia. 	\N
87	48	The Kresek occurs in early stage of plant growth of rice in	False Smut	Tungro virus	Bacterial leaf streak	BLB	BLB	The Kresek, a severe wilting symptom of Bacterial Leaf Blight (BLB) in rice, occurs in the early vegetative stage, typically 1-4 weeks after transplanting, affecting seedlings by causing them to wilt, roll, and turn yellow, often leading to complete plant death, and is caused by the bacterium Xanthomonas oryzae pv. oryzae entering through leaf wounds. 	\N
88	48	The varieties which belong to species Oryza glaberrima are found in	Africa	Asia	Europe	America	Africa	Varieties of Oryza glaberrima, known as African rice, are found primarily in West Africa, where this species was domesticated and traditionally cultivated, although its cultivation is declining as it's replaced by Asian rice (Oryza sativa), except for some specific regions like southern Senegal where farmers still grow it for cultural reasons, notes ScienceDirect.com, ScienceDirect.com, PNAS, and Wikipedia. 	\N
\.


--
-- Data for Name: mock_tests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.mock_tests (id, title, scheduled_date, total_questions, duration_minutes, created_at, subject, difficulty, participants, file_url, mcqs, user_id, start_time, end_time, description, status) FROM stdin;
48	Agronomy Test Series - 1	\N	4	10	2026-01-08 04:23:38.506	Agriculture 	Easy	0	\N	\N	\N	\N	\N	General instructions for Quiz :\r\n1. Starting the Quiz : Click the "Start Quiz" button to begin. The quiz will be displayed with a timer, and you can see your progress and answer choices. \r\n\r\n2. Navigating Questions : Use the "Prev" and "Next" buttons to move between questions. You can also click on the question numbers in the navigation box to jump to a specific question. \r\n\r\n3. Answering Questions : Select an option for each question by clicking on the radio button next to your choice. The selected option will be highlighted. You can only select one option per question. \r\n\r\n4. Clearing Answers : If you want to change your answer, click the "Clear Response" button to deselect your current choice. \r\n\r\n5. Reviewing Results : After completing the quiz, click "Next" on the last question to see your results. You will be shown the number of correct, incorrect, and unanswered questions, along with the total time taken. \r\n\r\n6. Retaking the Quiz : If you want to try the quiz again, click the "Retake Quiz" button on the results page. \r\n\r\n7. Returning Home : To return to the home page, click the "Home" button on the results page.	scheduled
\.


--
-- Data for Name: notes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notes (id, title, category, author, pages, downloads, rating, price, featured, file_url, preview_content, created_at, updated_at, description, tags, summary, embedding, cover_url, user_id, new_id, cached_preview, preview_generated, category_id) FROM stdin;
57	Agriculture Heritage in India	Agriculture	agrigyan	7	0	0	0.00	f	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/notes/1767781057213-lec01%20%20Agriculture%20Heritage%20in%20India.pdf		2026-01-07 10:17:38.417	2026-01-07 10:17:38.417	This article provides a comprehensive agronomy lecture notes PDF for agriculture students. It covers core topics in agronomy including principles of the field, water and irrigation management, major crop types like grain legumes and oil seeds, commercial crops, field crops, weed control, pest and disease management, seed technology, crop breeding and more.	\N	\N	\N	\N	1f1956c4-8770-4411-a450-4a415cd2c9fa	ea6c799e-cf37-47bc-bbf0-da482699b76c	\N	f	\N
74	LECTURE NOTES Course No: AECO 341 AGRICULTURAL MARKETING	Agriculture	Dr. D. V. Sankara Rao, Dr.D. V. Subba Rao	134	0	0	150.00	f	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/notes/1767931146301-II-Year-II-Sem_Agri-Marketing_ANGRAU_20.04.2020.pdf		2026-01-09 03:59:07.679	2026-01-09 03:59:07.679	LECTURE NOTES	\N	\N	\N	\N	1f1956c4-8770-4411-a450-4a415cd2c9fa	c4bf416e-51a8-4297-8e12-494edf949e0d	\N	f	\N
\.


--
-- Data for Name: notes_highlights; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notes_highlights (id, user_id, note_id, page, x_pct, y_pct, w_pct, h_pct, color, created_at) FROM stdin;
\.


--
-- Data for Name: notes_purchase; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notes_purchase (id, user_id, note_id, purchased_at) FROM stdin;
e54b4f95-08a4-49b3-bc10-ee691a7fe5ee	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	58	2026-01-07 11:58:58.167+00
df397833-6126-4391-a382-e17c262b6ba7	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	57	2026-01-08 08:22:30.708+00
c03eaf76-46f0-41d0-90a2-ec5e4a283fb6	f8433f32-428c-4011-8cd0-64ce50fca8f9	57	2026-02-09 03:46:35.366+00
\.


--
-- Data for Name: notes_read_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notes_read_history (id, user_id, note_id, last_page, updated_at) FROM stdin;
decd4899-ef3e-4968-9ba6-8bd9879e85e4	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	57	5	2026-02-09 03:30:28.641
e865a74d-fd12-4946-89ad-c40de0e05452	f8433f32-428c-4011-8cd0-64ce50fca8f9	57	7	2026-02-09 03:46:44.705
\.


--
-- Data for Name: notification_drafts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notification_drafts (id, subject, message, recipient_type, notification_type, custom_list, created_at) FROM stdin;
\.


--
-- Data for Name: notification_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notification_logs (id, subject, message, recipient_type, notification_type, delivered_count, custom_list, created_at) FROM stdin;
\.


--
-- Data for Name: payment_methods; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payment_methods (id, user_id, provider, display_name, last4, expiry, is_default, metadata, created_at) FROM stdin;
\.


--
-- Data for Name: payments_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payments_transactions (id, user_id, plan_id, amount, currency, method, status, description, created_at, external_ref, payment_id, updated_at) FROM stdin;
e8296be8-d0e3-41ba-b396-d42f143cb22e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	570	INR	razorpay	created	\N	2026-01-07 06:19:15.813178+00	order_S0t4Hrp6Ig2MhD	\N	2026-02-09 06:37:41.222694+00
8908bb0b-3288-4f07-8fdb-6cac9e2e4674	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	70	INR	razorpay	created	\N	2026-01-07 07:03:41.912962+00	order_S0tpDuwc8h5MQ5	\N	2026-02-09 06:37:41.222694+00
90f0b3ee-a23a-41e2-be9e-9054bd2d0065	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	0	INR	system	completed	Subscription canceled	2026-01-07 08:36:13.374035+00	\N	\N	2026-02-09 06:37:41.222694+00
11b7e1eb-7e21-4fe0-968a-649924fb266a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	250	INR	razorpay	created	\N	2026-01-07 09:35:53.018805+00	order_S0wPz1sFkvgNOt	\N	2026-02-09 06:37:41.222694+00
19e6a5d7-5a7e-4929-8955-b85c29b941ef	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	150	INR	razorpay	created	\N	2026-01-09 04:00:24.332162+00	order_S1dlqWIYItQKZb	\N	2026-02-09 06:37:41.222694+00
f9613b7c-879f-42c1-a393-7dc086d0f0fd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-01-13 04:25:55.138906+00	order_S3ELHGkHxYUWfl	\N	2026-02-09 06:37:41.222694+00
e23640ee-4662-47b3-9c0b-1be53d246e42	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-01-16 04:01:01.275913+00	order_S4PWL6dY95fB9Y	\N	2026-02-09 06:37:41.222694+00
02db2e7d-2d40-4c05-b1cc-e89740177999	f8433f32-428c-4011-8cd0-64ce50fca8f9	\N	200	INR	razorpay	created	\N	2026-01-19 10:11:57.665889+00	order_S5hRXNvqWAM2Jr	\N	2026-02-09 06:37:41.222694+00
4bc7503b-cb05-428d-9431-b12aa05139b7	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	150	INR	razorpay	created	\N	2026-01-27 04:01:01.795127+00	order_S8lOfodp31xVBG	\N	2026-02-09 06:37:41.222694+00
2191c2ed-275f-4a0d-8ad7-08bb97241188	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-02-09 03:27:58.158095+00	order_SDtmJg2SraUxIP	\N	2026-02-09 06:37:41.222694+00
db78cf13-646c-4259-bc35-8d0172699862	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	created	\N	2026-02-09 03:36:38.530528+00	order_SDtvTgtQUEZj3M	\N	2026-02-09 06:37:41.222694+00
e8f5a9c9-77d6-4c95-977c-bccce7fe4ffa	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	created	\N	2026-02-09 03:56:11.022238+00	order_SDuG7eL644ji0O	\N	2026-02-09 06:37:41.222694+00
3ef70f1b-868b-4c71-9574-8a1a797fabd3	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-02-09 05:23:12.200369+00	order_SDvk2gw027M91d	\N	2026-02-09 06:37:41.222694+00
30391b44-9265-4a43-86a6-ea698e1a5855	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-02-09 05:27:14.686148+00	order_SDvoJOJ4hcpodX	\N	2026-02-09 06:37:41.222694+00
d2c495d5-0182-491e-8af6-705fbe771de2	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	created	\N	2026-02-09 05:28:50.051263+00	order_SDvpzUN9mc0WRD	\N	2026-02-09 06:37:41.222694+00
ae36794e-ee49-4de8-8c04-d0f71d837e5a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-02-09 05:38:26.202012+00	order_SDw08NxnU8Fkky	\N	2026-02-09 06:37:41.222694+00
7f1f4658-c5e2-4b34-ae38-f2d08eaf5a9d	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	created	\N	2026-02-09 05:39:34.515395+00	order_SDw1KwfAcRxkgo	\N	2026-02-09 06:37:41.222694+00
bfa09793-9921-4ada-b625-5ab5a9268274	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-02-09 05:43:20.540507+00	order_SDw5JdwpUgMYdn	\N	2026-02-09 06:37:41.222694+00
9f21f784-67a5-4bed-b866-fad9d0ec1838	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-02-09 05:53:47.539259+00	order_SDwGM3Va4cAI3u	\N	2026-02-09 06:37:41.222694+00
f47b091a-8136-4485-b177-a7887ee0aa04	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	created	\N	2026-02-09 05:55:49.650705+00	order_SDwIVLokPN28Bs	\N	2026-02-09 06:37:41.222694+00
0b03b302-a0d1-4aab-b7cc-979750ae13db	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	created	\N	2026-02-09 06:03:01.566765+00	order_SDwQ6lSvTwab3v	\N	2026-02-09 06:37:41.222694+00
b3fd587b-0fb2-4aa9-b09b-90ec8d6e2a27	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	created	\N	2026-02-09 06:11:05.268882+00	order_SDwYcmgsKpM98p	\N	2026-02-09 06:37:41.222694+00
8893fbd0-bda5-4b35-b1f5-71eb36763a0d	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	created	\N	2026-02-09 06:17:30.55856+00	order_SDwfPKtEvawhLq	\N	2026-02-09 06:37:41.222694+00
bbfccfd8-9e8c-4599-99e6-f004a7106cf4	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	created	\N	2026-02-09 06:29:42.723513+00	order_SDwsIcMhfcIJZ4	\N	2026-02-09 06:37:41.222694+00
a214298d-716e-4824-960f-05b1ee04e7ed	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	paid	\N	2026-02-09 06:37:50.578686+00	order_SDx0t8GRGplxx9	pay_SDx0zlpzr9yDgq	2026-02-09 06:38:12.281+00
cedb5b13-aef0-4a50-9a07-46ecdeaab6a0	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	200	INR	razorpay	paid	\N	2026-02-09 06:50:33.462599+00	order_SDxEJrd4MrcEjf	pay_SDxEPyvQ7f1AXE	2026-02-09 06:50:52.645+00
614a0fa8-87c9-407a-a451-b7df4bd374c4	f8433f32-428c-4011-8cd0-64ce50fca8f9	\N	200	INR	razorpay	paid	\N	2026-02-09 06:56:50.104094+00	order_SDxKwtItIma4tE	pay_SDxLQYHHI9SgU1	2026-02-09 06:57:36.799+00
d5cf2493-5582-412f-8b09-fc526835b5dc	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	200	INR	razorpay	paid	\N	2026-02-09 07:14:05.447051+00	order_SDxdAzhNkXXLSB	pay_SDxdaKn3f8CwiW	2026-02-09 07:14:52.748+00
90d4f52c-43df-450a-abd5-806018aca157	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	150	INR	razorpay	paid	\N	2026-02-09 07:17:19.583471+00	order_SDxgavLXcm3ZKK	pay_SDxh2SNTjBs4Uj	2026-02-09 07:18:06.719+00
de5e59c5-3a35-4802-9de2-df7e3385c6dd	f8433f32-428c-4011-8cd0-64ce50fca8f9	\N	150	INR	razorpay	paid	\N	2026-02-09 08:13:32.892286+00	order_SDydz2Er4obV7U	pay_SDyeyiHFTAW3se	2026-02-09 08:14:52.902+00
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.profiles (id, full_name, created_at, plan, status, email, role, first_name, last_name, phone, dob, institution, field_of_study, academic_level, bio, avatar_url, email_notifications, push_notifications, account_status, total_spent, password_hash, must_reset_password, reset_token, reset_token_expires) FROM stdin;
782c37df-f571-4390-bd69-fefdb0e13cf5	harith	2025-11-19 09:07:19.191641+00	\N	active	harith@gmail.com	User	harith	kp	456546678	\N	\N	\N	Graduated	\N	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/avatars/avatars/782c37df-f571-4390-bd69-fefdb0e13cf5-1763630716714.png	{"recommendations": false}	{}	active	0	$2b$12$qL4w8NCOqz7Ucq5P0hJ.lk5Pu35Y6ibE5Rtq5AzkJh	t	\N	\N
f8433f32-428c-4011-8cd0-64ce50fca8f9	Kevin Jo	2026-01-12 03:26:05.784184+00	free	active	kevin01@gmail.com	User	Kevin	Jo	\N	\N	\N	\N	\N	\N	\N	{}	{}	active	0	$2b$12$qL4w8NCOqz7Ucq5P0hJ.lk5Pu35Y6ibE5Rtq5AzkJh	t	\N	\N
cdff310d-1cbf-4803-8c8b-b93195ac374f	Test user	2026-02-10 03:20:16.466964+00	free	active	testuser@gmail.com	User	Test	user	\N	2026-02-10	\N	\N	\N	\N	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/avatars/avatars/cdff310d-1cbf-4803-8c8b-b93195ac374f-1770693676442.png	{}	{}	active	0	$2b$12$qL4w8NCOqz7Ucq5P0hJ.lk5Pu35Y6ibE5Rtq5AzkJh	t	\N	\N
1f1956c4-8770-4411-a450-4a415cd2c9fa	\N	2025-11-11 08:31:14.977624+00	\N	active	superadmin@gmail.com	super_admin	\N	\N	\N	\N	\N	\N	\N	\N	\N	{}	{}	active	0	$2b$12$qL4w8NCOqz7Ucq5P0hJ.lk5Pu35Y6ibE5Rtq5AzkJh	t	\N	\N
7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Jarardh Jacob  C	2025-11-24 06:03:00.244384+00	free	active	jarardhc@gmail.com	User	Jarardh Jacob 	C	9968765432	2001-01-01	ABC College 	Agriculture 	Final Year 	This is my 📚.....	https://ouzlhvbgfuhwfnafvfxe.supabase.co/storage/v1/object/public/avatars/avatars/7e9011b6-a3c8-4c9b-8af6-5050baf0eafb-1766135784621.png	{}	{}	active	0	$2b$12$qL4w8NCOqz7Ucq5P0hJ.lk5Pu35Y6ibE5Rtq5AzkJh	t	\N	\N
\.


--
-- Data for Name: purchases; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.purchases (id, user_id, status, purchased_at, book_id) FROM stdin;
\.


--
-- Data for Name: pyq_papers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pyq_papers (id, subject_id, year, type, title, file_url, file_size, created_at, file_path) FROM stdin;
\.


--
-- Data for Name: pyq_subjects; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pyq_subjects (id, name, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: reports; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.reports (id, name, description, format, file_url, created_at) FROM stdin;
\.


--
-- Data for Name: revenue; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.revenue (id, amount, created_at, user_id, item_type, old_item_id, item_id, payment_id) FROM stdin;
520	0	2026-01-07 08:36:13.374035	\N	\N	\N	\N	\N
521	250	2026-01-07 09:35:53.018805	\N	\N	\N	\N	\N
522	150	2026-01-09 04:00:24.332162	\N	\N	\N	\N	\N
523	200	2026-01-13 04:25:55.138906	\N	\N	\N	\N	\N
524	200	2026-01-16 04:01:01.275913	\N	\N	\N	\N	\N
525	200	2026-01-19 10:11:57.665889	\N	\N	\N	\N	\N
526	150	2026-01-27 04:01:01.795127	\N	\N	\N	\N	\N
527	200	2026-02-09 03:27:58.158095	\N	\N	\N	\N	\N
528	200	2026-02-09 03:36:38.530528	\N	\N	\N	\N	\N
529	200	2026-02-09 03:56:11.022238	\N	\N	\N	\N	\N
530	200	2026-02-09 05:23:12.200369	\N	\N	\N	\N	\N
531	200	2026-02-09 05:27:14.686148	\N	\N	\N	\N	\N
532	200	2026-02-09 05:28:50.051263	\N	\N	\N	\N	\N
533	200	2026-02-09 05:38:26.202012	\N	\N	\N	\N	\N
534	200	2026-02-09 05:39:34.515395	\N	\N	\N	\N	\N
535	200	2026-02-09 05:43:20.540507	\N	\N	\N	\N	\N
536	200	2026-02-09 05:53:47.539259	\N	\N	\N	\N	\N
537	200	2026-02-09 05:55:49.650705	\N	\N	\N	\N	\N
538	200	2026-02-09 06:03:01.566765	\N	\N	\N	\N	\N
539	200	2026-02-09 06:11:05.268882	\N	\N	\N	\N	\N
540	200	2026-02-09 06:17:30.55856	\N	\N	\N	\N	\N
541	200	2026-02-09 06:29:42.723513	\N	\N	\N	\N	\N
542	200	2026-02-09 06:37:50.578686	\N	\N	\N	\N	\N
543	200	2026-02-09 06:50:33.462599	\N	\N	\N	\N	\N
544	200	2026-02-09 06:56:50.104094	\N	\N	\N	\N	\N
545	200	2026-02-09 07:14:05.447051	\N	\N	\N	\N	\N
546	150	2026-02-09 07:17:19.583471	\N	\N	\N	\N	\N
547	150	2026-02-09 08:13:32.892286	\N	\N	\N	\N	\N
548	200	2026-02-10 03:22:22.801941	\N	\N	\N	\N	\N
549	19.99	2026-02-10 04:30:42.017368	\N	\N	\N	\N	\N
550	0	2026-02-10 04:37:29.072685	\N	\N	\N	\N	\N
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.roles (id, name, permissions, created_at) FROM stdin;
207ce34b-375a-4091-a6d3-26d92f5eaee2	Super Admin	{all}	2025-11-07 09:21:29.447764+00
c99b453d-bb1c-4fb1-9036-2c65a63a57d5	Content Manager	{content:write,drm:manage}	2025-11-07 09:21:29.447764+00
dfe1cd79-dc57-4430-b863-6304f56dcaf4	Support	{users:view,tickets:reply}	2025-11-07 09:21:29.447764+00
\.


--
-- Data for Name: saved_jobs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.saved_jobs (id, user_id, job_id, saved_at) FROM stdin;
\.


--
-- Data for Name: study_notes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.study_notes (id, folder_id, title, file_path, file_name, created_by, created_at, subject_id, uploaded_by) FROM stdin;
\.


--
-- Data for Name: study_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.study_sessions (id, user_id, duration, created_at) FROM stdin;
1	1f1956c4-8770-4411-a450-4a415cd2c9fa	2	2025-11-18 09:59:31.536199+00
2	1f1956c4-8770-4411-a450-4a415cd2c9fa	1.5	2025-11-18 09:59:31.536199+00
3	1f1956c4-8770-4411-a450-4a415cd2c9fa	0.8	2025-11-18 09:59:31.536199+00
4	782c37df-f571-4390-bd69-fefdb0e13cf5	3	2025-11-18 09:59:31.536199+00
5	3dd44a33-02b1-4423-8af5-41397f681346	0.001788611111111111	2025-11-25 04:39:29.903782+00
6	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0016558333333333334	2025-11-25 11:25:24.597186+00
7	782c37df-f571-4390-bd69-fefdb0e13cf5	0.005790555555555556	2025-11-25 11:27:38.115553+00
8	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0028444444444444446	2025-11-25 11:30:37.469704+00
9	782c37df-f571-4390-bd69-fefdb0e13cf5	0.049847777777777776	2025-11-25 11:35:09.132522+00
10	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0015380555555555555	2025-11-25 11:41:46.412909+00
11	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0019272222222222223	2025-11-25 11:43:42.926096+00
12	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0151475	2025-11-25 11:46:47.267963+00
13	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0028127777777777778	2025-11-25 11:47:06.706896+00
14	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0011755555555555556	2025-11-25 11:50:03.430534+00
15	782c37df-f571-4390-bd69-fefdb0e13cf5	0.00013388888888888888	2025-11-25 11:51:35.161897+00
16	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.00033583333333333333	2025-11-26 05:25:02.850709+00
17	782c37df-f571-4390-bd69-fefdb0e13cf5	0.027719722222222222	2025-11-26 05:27:17.587679+00
18	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.0007947222222222223	2025-11-26 05:32:58.779597+00
19	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.00006083333333333333	2025-11-26 05:33:16.179135+00
20	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.0004955555555555555	2025-11-26 05:33:17.40236+00
21	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.01436611111111111	2025-11-26 05:35:10.352003+00
22	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.0000861111111111111	2025-11-26 06:08:42.699716+00
23	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.0003380555555555556	2025-11-26 06:08:42.803234+00
24	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.0007538888888888889	2025-11-26 06:08:44.340046+00
25	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.041041666666666664	2025-11-26 07:18:04.86271+00
26	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.04110388888888889	2025-11-26 07:18:05.190563+00
27	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.013215277777777777	2025-11-26 07:21:19.749537+00
28	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.01393888888888889	2025-11-26 07:21:21.964481+00
29	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.022611944444444445	2025-11-26 08:31:07.06269+00
30	782c37df-f571-4390-bd69-fefdb0e13cf5	0.04413638888888889	2025-11-26 08:38:48.757922+00
31	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.001990833333333333	2025-11-26 08:40:36.401879+00
32	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0005830555555555555	2025-11-26 09:08:00.51387+00
33	782c37df-f571-4390-bd69-fefdb0e13cf5	0.006881944444444445	2025-11-26 09:16:47.374018+00
34	782c37df-f571-4390-bd69-fefdb0e13cf5	0.014418611111111111	2025-11-26 09:27:18.893764+00
35	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0006591666666666666	2025-11-26 09:27:31.734475+00
36	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.002076388888888889	2025-11-26 11:09:46.232844+00
37	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.002832777777777778	2025-11-26 11:09:46.681233+00
38	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.00006638888888888889	2025-11-26 11:10:17.571058+00
39	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.087005	2025-11-26 11:49:27.492201+00
40	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.0005908333333333333	2025-11-27 03:18:54.522945+00
41	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.0038666666666666667	2025-11-27 03:19:18.161649+00
42	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0007930555555555555	2025-11-27 04:46:44.640731+00
43	782c37df-f571-4390-bd69-fefdb0e13cf5	0.008006666666666667	2025-11-27 07:27:19.873795+00
44	782c37df-f571-4390-bd69-fefdb0e13cf5	0.00003138888888888889	2025-11-27 09:36:06.183863+00
45	782c37df-f571-4390-bd69-fefdb0e13cf5	0.001175	2025-11-29 06:27:45.633256+00
46	782c37df-f571-4390-bd69-fefdb0e13cf5	0.5230305555555556	2025-12-01 09:48:08.557749+00
47	782c37df-f571-4390-bd69-fefdb0e13cf5	0.001651111111111111	2025-12-01 09:51:56.821186+00
48	782c37df-f571-4390-bd69-fefdb0e13cf5	0.000043333333333333334	2025-12-01 09:53:34.986465+00
49	782c37df-f571-4390-bd69-fefdb0e13cf5	0.033345	2025-12-01 09:55:42.523824+00
50	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0003177777777777778	2025-12-01 09:57:30.229685+00
51	782c37df-f571-4390-bd69-fefdb0e13cf5	0.00030972222222222225	2025-12-01 09:59:49.789159+00
52	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.012039444444444445	2025-12-01 10:11:50.339972+00
53	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.02206277777777778	2025-12-02 03:32:10.950183+00
54	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.0050305555555555555	2025-12-02 06:42:50.715082+00
55	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	0.001186111111111111	2025-12-02 06:48:03.957638+00
56	782c37df-f571-4390-bd69-fefdb0e13cf5	0.00028083333333333335	2025-12-03 03:17:26.940674+00
57	782c37df-f571-4390-bd69-fefdb0e13cf5	0.001966388888888889	2025-12-03 03:18:12.844606+00
58	782c37df-f571-4390-bd69-fefdb0e13cf5	0.0010697222222222221	2025-12-03 03:18:27.341978+00
\.


--
-- Data for Name: subjects; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.subjects (id, value, label) FROM stdin;
53	ugc-net	UGC NET
54	icar-jrf	ICAR JRF
55	icar-srf	ICAR SRF
\.


--
-- Data for Name: submissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.submissions (id, exam_id, user_id, answer_text, answer_file_path, answer_file_name, submitted_at, score, admin_message) FROM stdin;
\.


--
-- Data for Name: subscription_plans; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.subscription_plans (id, slug, name, price, period, features, popular, created_at) FROM stdin;
1	monthly	Monthly	19.99	monthly	["Access to 1,000+ e-books", "10 mock tests per month", "Basic notes repository"]	f	2025-11-18 05:09:59.218842+00
2	annual	Annual	199.99	annual	["Access to 5,000+ e-books", "Unlimited mock tests", "Premium notes repository"]	t	2025-11-18 05:09:59.218842+00
\.


--
-- Data for Name: subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.subscriptions (id, user_id, plan, amount, created_at, status, end_date) FROM stdin;
\.


--
-- Data for Name: system_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.system_settings (id, platform_name, support_email, support_phone, default_currency, registrations_enabled, uploads_enabled, maintenance_mode, backup_retention_days, last_backup, created_at, updated_at) FROM stdin;
224cd561-0fa3-4a6a-81b5-0dee1a6a62bd	FarmInk Forum	support@formink.com	+1 (555) 123-4567	USD	t	t	f	30	\N	2025-11-07 09:21:10.835745+00	2025-11-26 03:58:04.899+00
\.


--
-- Data for Name: test_attempts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.test_attempts (id, user_id, test_id, answers, completed_questions, score, rank, started_at, completed_at) FROM stdin;
\.


--
-- Data for Name: test_results; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.test_results (id, user_id, test_id, score, created_at) FROM stdin;
\.


--
-- Data for Name: user_activity; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_activity (id, user_id, action, type, details, created_at) FROM stdin;
11	1f1956c4-8770-4411-a450-4a415cd2c9fa	Purchased a book	purchase	Book ID: a5795c2e-bf4a-4190-99ce-c79a01b9e536	2025-11-18 09:59:59.878467+00
12	1f1956c4-8770-4411-a450-4a415cd2c9fa	Logged in	login	\N	2025-11-18 07:59:59.878467+00
13	1f1956c4-8770-4411-a450-4a415cd2c9fa	Opened book	content	Reading progress updated	2025-11-17 09:59:59.878467+00
14	782c37df-f571-4390-bd69-fefdb0e13cf5	Activated subscription	subscription	Monthly plan	2025-11-15 09:59:59.878467+00
\.


--
-- Data for Name: user_books; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_books (id, user_id, progress, status, updated_at, book_id) FROM stdin;
\.


--
-- Data for Name: user_cart; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_cart (id, user_id, book_id, note_id, quantity, added_at) FROM stdin;
1e2de9b7-6f14-4364-b584-27e803ad4936	782c37df-f571-4390-bd69-fefdb0e13cf5	3ca5b016-7c38-4391-a929-c7351709cd60	\N	1	2026-01-03 05:07:49.663462+00
\.


--
-- Data for Name: user_devices; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_devices (id, user_id, fingerprint, created_at) FROM stdin;
\.


--
-- Data for Name: user_library; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_library (id, user_id, progress, added_at, book_id, last_page, completed_at) FROM stdin;
97	f8433f32-428c-4011-8cd0-64ce50fca8f9	57	2026-01-13 03:38:11.438856	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	485	\N
108	cdff310d-1cbf-4803-8c8b-b93195ac374f	4	2026-02-10 03:23:16.608	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	38	\N
107	cdff310d-1cbf-4803-8c8b-b93195ac374f	12	2026-02-10 03:22:05.935	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	51	\N
94	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	5	2026-01-07 09:52:05.064	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	21	\N
96	f8433f32-428c-4011-8cd0-64ce50fca8f9	56	2026-01-13 03:37:28.39	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	246	\N
104	782c37df-f571-4390-bd69-fefdb0e13cf5	0	2026-02-09 06:50:54.424	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	3	\N
95	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	93	2026-01-08 04:01:57.749615	c06cae3a-0e9b-4aee-90dd-e9fafb88aefd	797	\N
99	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2026-02-09 03:34:59.466	14af9fde-cd3b-41ec-9c82-fb0ecdce7078	8	\N
\.


--
-- Data for Name: user_notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_notifications (id, user_id, title, message, link, is_read, created_at) FROM stdin;
2059	c90f6497-45ff-4ca8-82ae-bd0029ece732	Add New Book 📙 	My Book	/notifications	f	2025-11-24 15:38:16.528653+00
2063	acd103fd-7adb-4bfa-9322-39d5682d5e4f	Add New Book 📙 	My Book	/notifications	f	2025-11-24 15:38:17.32561+00
2072	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	New Book 	I am added New Book 📙 	/notifications	t	2025-12-05 04:49:16.072429+00
2167	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Completed	Your writing order (#45) is now ready.	\N	t	2025-12-30 09:15:05.872241+00
2157	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Accepted	Your writing request (#42) is now being worked on.	\N	t	2025-12-20 03:49:41.141446+00
2158	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Accepted	Your writing request (#42) is now being worked on.	\N	t	2025-12-20 03:50:04.71984+00
2079	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	asd	asdgfgh	/notifications	t	2025-12-05 04:58:45.962122+00
2086	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	hi	testing	/notifications	t	2025-12-05 05:00:22.017799+00
2093	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	hi	testing	/notifications	t	2025-12-05 05:15:44.698371+00
2058	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Add New Book 📙 	My Book	/notifications	t	2025-11-24 15:38:16.324302+00
2080	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	asd	asdgfgh	/notifications	t	2025-12-05 04:58:46.191964+00
2060	1f1956c4-8770-4411-a450-4a415cd2c9fa	Add New Book 📙 	My Book	/notifications	t	2025-11-24 15:38:16.733193+00
2074	c90f6497-45ff-4ca8-82ae-bd0029ece732	New Book 	I am added New Book 📙 	/notifications	f	2025-12-05 04:49:16.523111+00
2075	1f1956c4-8770-4411-a450-4a415cd2c9fa	New Book 	I am added New Book 📙 	/notifications	f	2025-12-05 04:49:16.725793+00
2078	acd103fd-7adb-4bfa-9322-39d5682d5e4f	New Book 	I am added New Book 📙 	/notifications	f	2025-12-05 04:49:17.323795+00
2100	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	hi	hi	/notifications	t	2025-12-05 05:16:31.98526+00
2073	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	New Book 	I am added New Book 📙 	/notifications	t	2025-12-05 04:49:16.310988+00
2081	c90f6497-45ff-4ca8-82ae-bd0029ece732	asd	asdgfgh	/notifications	f	2025-12-05 04:58:46.39405+00
2082	1f1956c4-8770-4411-a450-4a415cd2c9fa	asd	asdgfgh	/notifications	f	2025-12-05 04:58:46.592382+00
2085	acd103fd-7adb-4bfa-9322-39d5682d5e4f	asd	asdgfgh	/notifications	f	2025-12-05 04:58:47.188916+00
2087	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	hi	testing	/notifications	t	2025-12-05 05:00:22.461667+00
2088	c90f6497-45ff-4ca8-82ae-bd0029ece732	hi	testing	/notifications	f	2025-12-05 05:00:22.915568+00
2089	1f1956c4-8770-4411-a450-4a415cd2c9fa	hi	testing	/notifications	f	2025-12-05 05:00:23.338191+00
2092	acd103fd-7adb-4bfa-9322-39d5682d5e4f	hi	testing	/notifications	f	2025-12-05 05:00:24.594645+00
2094	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	hi	testing	/notifications	t	2025-12-05 05:15:45.120028+00
2101	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	hi	hi	/notifications	t	2025-12-05 05:16:32.419226+00
2161	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Completed	Your writing order (#42) is now ready.	\N	t	2025-12-29 10:34:22.577151+00
2164	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Accepted	Your writing request (#44) is now in progress.	\N	t	2025-12-30 08:41:13.806494+00
2071	782c37df-f571-4390-bd69-fefdb0e13cf5	New Message From Admin	Admin replied to your writing order #19: "hi"	\N	t	2025-11-25 07:33:21.756+00
2095	c90f6497-45ff-4ca8-82ae-bd0029ece732	hi	testing	/notifications	f	2025-12-05 05:15:45.53961+00
2096	1f1956c4-8770-4411-a450-4a415cd2c9fa	hi	testing	/notifications	f	2025-12-05 05:15:45.945747+00
2099	acd103fd-7adb-4bfa-9322-39d5682d5e4f	hi	testing	/notifications	f	2025-12-05 05:15:47.207495+00
2102	c90f6497-45ff-4ca8-82ae-bd0029ece732	hi	hi	/notifications	f	2025-12-05 05:16:32.8435+00
2103	1f1956c4-8770-4411-a450-4a415cd2c9fa	hi	hi	/notifications	f	2025-12-05 05:16:33.279231+00
2068	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Accepted	Your writing request (#20) is now being worked on.	\N	t	2025-11-25 05:17:17.012+00
2062	782c37df-f571-4390-bd69-fefdb0e13cf5	Add New Book 📙 	My Book	/notifications	t	2025-11-24 15:38:17.125633+00
2069	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Rejected	Your writing order #21 was rejected. Reason: 	\N	t	2025-11-25 05:17:21.301+00
2077	782c37df-f571-4390-bd69-fefdb0e13cf5	New Book 	I am added New Book 📙 	/notifications	t	2025-12-05 04:49:17.12499+00
2084	782c37df-f571-4390-bd69-fefdb0e13cf5	asd	asdgfgh	/notifications	t	2025-12-05 04:58:46.991604+00
2076	3dd44a33-02b1-4423-8af5-41397f681346	New Book 	I am added New Book 📙 	/notifications	t	2025-12-05 04:49:16.929335+00
2083	3dd44a33-02b1-4423-8af5-41397f681346	asd	asdgfgh	/notifications	t	2025-12-05 04:58:46.791578+00
2090	3dd44a33-02b1-4423-8af5-41397f681346	hi	testing	/notifications	t	2025-12-05 05:00:23.757029+00
2097	3dd44a33-02b1-4423-8af5-41397f681346	hi	testing	/notifications	t	2025-12-05 05:15:46.367082+00
2104	3dd44a33-02b1-4423-8af5-41397f681346	hi	hi	/notifications	t	2025-12-05 05:16:33.70914+00
2098	782c37df-f571-4390-bd69-fefdb0e13cf5	hi	testing	/notifications	t	2025-12-05 05:15:46.794865+00
2091	782c37df-f571-4390-bd69-fefdb0e13cf5	hi	testing	/notifications	t	2025-12-05 05:00:24.183243+00
2106	acd103fd-7adb-4bfa-9322-39d5682d5e4f	hi	hi	/notifications	f	2025-12-05 05:16:34.541544+00
2126	aea41626-3127-4b2e-9103-d3f07855a3f3	Order Completed	Your writing order (#28) is now ready. Download or read it.	\N	t	2025-12-11 05:13:20.991+00
2116	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Completed	Your writing order (#20) is now ready. Download or read it.	\N	t	2025-12-06 06:50:18.832+00
2115	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Completed	Your writing order (#20) is now ready. Download or read it.	\N	t	2025-12-06 06:50:17.965+00
2113	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Completed	Your writing order (#19) is now ready. Download or read it.	\N	t	2025-12-06 06:40:09.918+00
2118	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Accepted	Your writing request (#23) is now being worked on.	\N	t	2025-12-06 07:09:03.304+00
2105	782c37df-f571-4390-bd69-fefdb0e13cf5	hi	hi	/notifications	t	2025-12-05 05:16:34.123718+00
2107	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Rejected	Your writing order #21 was rejected. Reason: hi	\N	t	2025-12-06 06:39:15.722+00
2108	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Rejected	Your writing order #21 was rejected. Reason: hi	\N	t	2025-12-06 06:39:15.747+00
2109	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Rejected	Your writing order #21 was rejected. Reason: hi	\N	t	2025-12-06 06:39:15.718+00
2168	2007ba64-d8c0-4692-82fc-c4a476f1e1da	Order Accepted	Your writing request (#47) is now in progress.	\N	t	2026-01-07 04:57:39.827613+00
2159	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Accepted	Your writing request (#42) is now in progress.	\N	t	2025-12-20 03:55:37.360725+00
2162	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Accepted	Your writing request (#43) is now in progress.	\N	t	2025-12-30 08:26:00.709516+00
2165	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Completed	Your writing order (#44) is now ready.	\N	t	2025-12-30 08:43:37.096786+00
2124	aea41626-3127-4b2e-9103-d3f07855a3f3	Writing Order Submitted	Your writing order "Test Title" has been submitted successfully.	\N	t	2025-12-11 04:35:10.5+00
2125	aea41626-3127-4b2e-9103-d3f07855a3f3	Order Accepted	Your writing request (#28) is now being worked on.	\N	t	2025-12-11 04:37:06.087+00
2160	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	New Message From Admin	Admin replied to your writing order #42: "started"	\N	t	2025-12-20 04:02:20.019702+00
2142	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	testingg	testing notification	\N	t	2025-12-16 11:16:49.643538+00
2110	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Accepted	Your writing request (#19) is now being worked on.	\N	t	2025-12-06 06:39:35.345+00
2111	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Accepted	Your writing request (#19) is now being worked on.	\N	t	2025-12-06 06:39:35.453+00
2112	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Accepted	Your writing request (#19) is now being worked on.	\N	t	2025-12-06 06:39:35.465+00
2131	e87de6a5-5954-437d-8d11-ccf33349a7de	Order Rejected	Your writing order #39 was rejected. Reason: 	\N	t	2025-12-12 09:15:45.218+00
2132	e87de6a5-5954-437d-8d11-ccf33349a7de	Order Rejected	Your writing order #39 was rejected. Reason: 	\N	t	2025-12-12 09:15:49.202+00
2133	e87de6a5-5954-437d-8d11-ccf33349a7de	Order Rejected	Your writing order #38 was rejected. Reason: 	\N	t	2025-12-12 09:15:53.216+00
2134	e87de6a5-5954-437d-8d11-ccf33349a7de	Order Rejected	Your writing order #37 was rejected. Reason: 	\N	t	2025-12-12 09:15:57.204+00
2135	e87de6a5-5954-437d-8d11-ccf33349a7de	Order Rejected	Your writing order #37 was rejected. Reason: 	\N	t	2025-12-12 09:16:01.131+00
2138	e87de6a5-5954-437d-8d11-ccf33349a7de	Order Rejected	Your writing order #39 was rejected. Reason: d	\N	t	2025-12-13 12:49:53.628972+00
2139	e87de6a5-5954-437d-8d11-ccf33349a7de	Order Rejected	Your writing order #39 was rejected. Reason: v	\N	t	2025-12-13 12:50:03.528071+00
2140	e87de6a5-5954-437d-8d11-ccf33349a7de	Test Message	Test Message Form Admin	dashboard	t	2025-12-15 09:15:16.899+00
2145	0bedcb4d-c806-4da7-a05b-20703e87115c	testingg	testing notification	\N	f	2025-12-16 11:16:49.643538+00
2146	cd450956-13a6-4840-bed2-5ec32adc6ec7	testingg	testing notification	\N	f	2025-12-16 11:16:49.643538+00
2147	765422e6-ec57-4dac-aa82-a15ad4c0482e	testingg	testing notification	\N	f	2025-12-16 11:16:49.643538+00
2148	2d651e0e-9917-479f-b802-47aadfb63c0c	testingg	testing notification	\N	f	2025-12-16 11:16:49.643538+00
2149	1f1956c4-8770-4411-a450-4a415cd2c9fa	testingg	testing notification	\N	f	2025-12-16 11:16:49.643538+00
2114	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Completed	Your writing order (#19) is now ready. Download or read it.	\N	t	2025-12-06 06:40:09.913+00
2119	782c37df-f571-4390-bd69-fefdb0e13cf5	New Message From Admin	Admin replied to your writing order #23: "hiii"	\N	t	2025-12-06 07:10:06.312+00
2117	782c37df-f571-4390-bd69-fefdb0e13cf5	New Message From Admin	Admin replied to your writing order #21: "HE"	\N	t	2025-12-06 06:57:38.287+00
2152	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	TESTING  NOTIFICATION 🔔 	TESTING NOTIFICATION MESSAGES 	\N	t	2025-12-17 04:03:20.512292+00
2151	1f1956c4-8770-4411-a450-4a415cd2c9fa	TESTING  NOTIFICATION 🔔 	TESTING NOTIFICATION MESSAGES 	\N	f	2025-12-17 04:03:20.512292+00
2155	0bedcb4d-c806-4da7-a05b-20703e87115c	TESTING  NOTIFICATION 🔔 	TESTING NOTIFICATION MESSAGES 	\N	f	2025-12-17 04:03:20.512292+00
2156	cd450956-13a6-4840-bed2-5ec32adc6ec7	TESTING  NOTIFICATION 🔔 	TESTING NOTIFICATION MESSAGES 	\N	f	2025-12-17 04:03:20.512292+00
2150	aea41626-3127-4b2e-9103-d3f07855a3f3	TESTING  NOTIFICATION 🔔 	TESTING NOTIFICATION MESSAGES 	\N	t	2025-12-17 04:03:20.512292+00
2141	aea41626-3127-4b2e-9103-d3f07855a3f3	testingg	testing notification	\N	t	2025-12-16 11:16:49.643538+00
2144	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	testingg	testing notification	\N	t	2025-12-16 11:16:49.643538+00
2154	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	TESTING  NOTIFICATION 🔔 	TESTING NOTIFICATION MESSAGES 	\N	t	2025-12-17 04:03:20.512292+00
2121	782c37df-f571-4390-bd69-fefdb0e13cf5	Writing Order Submitted	Your writing order "f" has been submitted successfully.	\N	t	2025-12-06 07:26:22.947+00
2120	782c37df-f571-4390-bd69-fefdb0e13cf5	Writing Order Submitted	Your writing order "f" has been submitted successfully.	\N	t	2025-12-06 07:26:18.434+00
2122	782c37df-f571-4390-bd69-fefdb0e13cf5	Writing Order Submitted	Your writing order "hi" has been submitted successfully.	\N	t	2025-12-10 08:47:28.057+00
2123	782c37df-f571-4390-bd69-fefdb0e13cf5	Writing Order Submitted	Your writing order "test" has been submitted successfully.	\N	t	2025-12-10 09:07:18.417+00
2127	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Accepted	Your writing request (#27) is now being worked on.	\N	t	2025-12-11 05:23:33.56+00
2128	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Completed	Your writing order (#27) is now ready. Download or read it.	\N	t	2025-12-11 05:23:53.064+00
2129	782c37df-f571-4390-bd69-fefdb0e13cf5	Writing Order Submitted	Your writing order "4" has been submitted successfully.	\N	t	2025-12-11 05:33:28.034+00
2130	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Rejected	Your writing order #40 was rejected. Reason: h	\N	t	2025-12-12 09:15:40.691+00
2136	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Accepted	Your writing request (#41) is now being worked on.	\N	t	2025-12-12 11:25:56.18816+00
2137	782c37df-f571-4390-bd69-fefdb0e13cf5	Order Completed	Your writing order (#41) is now ready. Download or read it.	\N	t	2025-12-12 11:26:05.878472+00
2143	782c37df-f571-4390-bd69-fefdb0e13cf5	testingg	testing notification	\N	t	2025-12-16 11:16:49.643538+00
2163	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Completed	Your writing order (#43) is now ready.	\N	t	2025-12-30 08:30:53.817181+00
2166	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	Order Accepted	Your writing request (#45) is now in progress.	\N	t	2025-12-30 09:13:41.031228+00
2153	782c37df-f571-4390-bd69-fefdb0e13cf5	TESTING  NOTIFICATION 🔔 	TESTING NOTIFICATION MESSAGES 	\N	t	2025-12-17 04:03:20.512292+00
2169	2007ba64-d8c0-4692-82fc-c4a476f1e1da	Order Completed	Your writing order (#47) is now ready.	\N	t	2026-01-07 04:58:03.98435+00
\.


--
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_preferences (user_id, theme, language, timezone, auto_save, sync_highlights, reading_reminders, updated_at) FROM stdin;
2570e2bf-29e0-47f0-9355-a187dfe6c37a	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-23 03:37:43.067
89a995c7-cd3c-43e6-8430-c41d11e31ecb	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-23 03:52:55.639
f9fce64d-faf4-4195-92eb-e40ed2253542	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-23 03:56:58.624
417bc17f-224f-4cca-8fd0-a70c96cde985	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-23 04:25:05.736
aea41626-3127-4b2e-9103-d3f07855a3f3	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-23 06:45:30.811
782c37df-f571-4390-bd69-fefdb0e13cf5	dark	English (US)	Asia/Kolkata	t	\N	t	2025-12-23 08:57:39.23
f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-23 09:10:02.343
1f1956c4-8770-4411-a450-4a415cd2c9fa	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-23 09:47:26.022
130bad80-c4d2-43f3-be2e-3f49678af7d2	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-23 09:54:02.577
7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	dark	English (US)	Asia/Kolkata	t	t	\N	2025-12-23 10:08:26.659
50c02d4a-6556-43ca-8d0e-6abefb6911fa	\N	\N	Asia/Kolkata	\N	\N	\N	2025-12-22 11:39:51.993
\.


--
-- Data for Name: user_profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_profiles (user_id, first_name, last_name, email, phone, dob, institution, field_of_study, academic_level, bio, avatar_url, language, timezone, theme, auto_save, sync_highlights, reading_reminders, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_security; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_security (user_id, two_factor_enabled, two_factor_method, last_password_change, created_at, updated_at) FROM stdin;
3dd44a33-02b1-4423-8af5-41397f681346	t	none	\N	2025-11-12 10:24:37.655402	2025-11-20 08:29:46.102775
782c37df-f571-4390-bd69-fefdb0e13cf5	t	sms	\N	2025-11-20 08:37:12.714481	2025-11-20 09:09:16.55
7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	f	none	\N	2025-12-16 11:37:16.229169	2025-12-16 11:37:19.571
\.


--
-- Data for Name: user_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_sessions (id, user_id, device_name, browser, location, ip_address, last_active, active, is_current, created_at, updated_at, device, user_agent, device_id, expires_at) FROM stdin;
197	f9fce64d-faf4-4195-92eb-e40ed2253542	\N	\N	::1	\N	2026-01-06 04:03:01.701	t	f	2025-12-30 04:20:39.705643+00	2025-12-30 04:20:39.705643+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	e6271fdd0bea292c86883f51352c7083a8a7d228b69e08fa34eacd9be26bc82a	2026-01-21 04:03:01.701
321	f8433f32-428c-4011-8cd0-64ce50fca8f9	\N	\N	::1	\N	2026-01-19 10:10:17.875	f	f	2026-01-12 03:26:49.237908+00	2026-01-12 03:26:49.237908+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	e6271fdd0bea292c86883f51352c7083a8a7d228b69e08fa34eacd9be26bc82a	2026-02-03 10:10:17.875
181	1f1956c4-8770-4411-a450-4a415cd2c9fa	\N	\N	::1	\N	2026-01-13 03:30:56.371	f	f	2025-12-29 11:28:21.876672+00	2025-12-29 11:28:21.876672+00	Unknown	Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:146.0) Gecko/20100101 Firefox/146.0	6dd74e5a958713b0923d7116b6b3987661184d8f681838462db99d205cfcbba5	2026-01-28 03:30:56.371
133	1f1956c4-8770-4411-a450-4a415cd2c9fa	\N	\N	::1	\N	2026-01-03 03:57:57.714	f	f	2025-12-23 10:06:51.779701+00	2025-12-23 10:06:51.779701+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	ad15deb1b46baca93b3608fbf411bdae9812840196358216c231b98cececc9ce	2026-01-18 03:57:57.714
336	1f1956c4-8770-4411-a450-4a415cd2c9fa	\N	\N	::1	\N	2026-02-25 05:23:53.257	t	f	2026-01-27 04:00:20.069197+00	2026-01-27 04:00:20.069197+00	Unknown	Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:147.0) Gecko/20100101 Firefox/147.0	9914002296e7feda23700fd7035542dffe1dd399b27d8a1c3ad591b5adc3f85d	2026-03-12 05:23:53.257
359	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	\N	::1	\N	2026-02-09 07:14:45.849	f	f	2026-02-09 03:34:25.786897+00	2026-02-09 03:34:25.786897+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	0b9871806993c9df98367a1bc001350141e0abc64cfbb2a36ca3b66902351604	2026-02-24 07:14:45.849
129	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	\N	::1	\N	2025-12-23 10:08:43.086	f	f	2025-12-23 09:45:35.949825+00	2025-12-23 09:45:35.949825+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	41a279fb1f4045be6b1b29525cf83f54ffc223b21a7a851736dcb95cee053b80	\N
168	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	\N	::1	\N	2026-01-01 09:42:17.756	f	f	2025-12-29 08:35:50.697562+00	2025-12-29 08:35:50.697562+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0	ad15deb1b46baca93b3608fbf411bdae9812840196358216c231b98cececc9ce	2026-01-16 09:42:17.756
335	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	\N	::1	\N	2026-02-09 06:50:05.391	f	f	2026-01-27 04:00:05.31268+00	2026-01-27 04:00:05.31268+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	0b9871806993c9df98367a1bc001350141e0abc64cfbb2a36ca3b66902351604	2026-02-24 06:50:05.391
348	f8433f32-428c-4011-8cd0-64ce50fca8f9	\N	\N	::1	\N	2026-02-09 06:39:40.395	t	f	2026-02-04 03:26:55.293646+00	2026-02-04 03:26:55.293646+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	0b9871806993c9df98367a1bc001350141e0abc64cfbb2a36ca3b66902351604	2026-02-24 06:39:40.395
143	1f1956c4-8770-4411-a450-4a415cd2c9fa	\N	\N	::1	\N	2026-01-08 09:17:26.726	f	f	2025-12-27 10:56:20.081593+00	2025-12-27 10:56:20.081593+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	e6271fdd0bea292c86883f51352c7083a8a7d228b69e08fa34eacd9be26bc82a	2026-01-23 09:17:26.726
130	1f1956c4-8770-4411-a450-4a415cd2c9fa	\N	\N	::1	\N	2025-12-23 09:49:50.445	f	f	2025-12-23 09:47:25.723632+00	2025-12-23 09:47:25.723632+00	Unknown	Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:146.0) Gecko/20100101 Firefox/146.0	0e74b29f9224915509271c152b72021c50d17b69255e41d58fdb4d5388f8f88d	\N
177	aea41626-3127-4b2e-9103-d3f07855a3f3	\N	\N	::1	\N	2026-01-07 06:49:54.376	t	f	2025-12-29 10:28:56.067532+00	2025-12-29 10:28:56.067532+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	e6271fdd0bea292c86883f51352c7083a8a7d228b69e08fa34eacd9be26bc82a	2026-01-22 06:49:54.376
354	1f1956c4-8770-4411-a450-4a415cd2c9fa	\N	\N	::1	\N	2026-02-07 09:27:49.811	f	f	2026-02-07 09:27:50.257662+00	2026-02-07 09:27:50.257662+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	0b9871806993c9df98367a1bc001350141e0abc64cfbb2a36ca3b66902351604	2026-02-22 09:27:49.811
185	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	\N	::1	\N	2025-12-29 11:58:23.402	f	f	2025-12-29 11:58:23.648744+00	2025-12-29 11:58:23.648744+00	Unknown	PostmanRuntime/7.51.0	d83eef8df7996dbab60d8ba12f2dd17ce14a59033ca142c7a768c4aa9490b21b	2026-01-13 11:58:23.402
155	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	\N	::1	\N	2026-01-03 04:26:13.5	f	f	2025-12-29 03:44:03.562167+00	2025-12-29 03:44:03.562167+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	e6271fdd0bea292c86883f51352c7083a8a7d228b69e08fa34eacd9be26bc82a	2026-01-18 04:26:13.5
385	782c37df-f571-4390-bd69-fefdb0e13cf5	\N	\N	::1	\N	2026-02-25 05:26:19.158	t	f	2026-02-25 05:25:51.861542+00	2026-02-25 05:25:51.861542+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	5859a2be74a1eac8cdca6193f336e66442c756e714ad042702acf50d7f9dea63	2026-03-12 05:26:19.158
132	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	\N	::1	\N	2026-01-16 04:00:24.142	f	f	2025-12-23 09:54:39.367236+00	2025-12-23 09:54:39.367236+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36	e6271fdd0bea292c86883f51352c7083a8a7d228b69e08fa34eacd9be26bc82a	2026-01-31 04:00:24.142
384	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	\N	\N	::1	\N	2026-02-25 05:26:59.101	t	f	2026-02-25 05:23:53.748959+00	2026-02-25 05:23:53.748959+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36	5859a2be74a1eac8cdca6193f336e66442c756e714ad042702acf50d7f9dea63	2026-03-12 05:26:59.101
377	cdff310d-1cbf-4803-8c8b-b93195ac374f	\N	\N	::1	\N	2026-02-10 04:36:26.061	t	f	2026-02-10 03:20:45.441778+00	2026-02-10 03:20:45.441778+00	"Windows"	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36	0b9871806993c9df98367a1bc001350141e0abc64cfbb2a36ca3b66902351604	2026-02-25 04:36:26.061
\.


--
-- Data for Name: user_stats; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_stats (id, user_id, tests_taken, average_score, best_rank, total_study_time, updated_at) FROM stdin;
1	acd103fd-7adb-4bfa-9322-39d5682d5e4f	1	85	1	0	2025-11-05 03:47:19.239
18	f9fce64d-faf4-4195-92eb-e40ed2253542	1	100	\N	1	2025-12-30 05:10:27.9082
14	c90f6497-45ff-4ca8-82ae-bd0029ece732	1	0	\N	330	2025-11-17 04:01:20.258098
2	3dd44a33-02b1-4423-8af5-41397f681346	7	\N	\N	999	2025-11-13 09:11:12.761
15	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	20	12	1	331	2025-12-03 13:29:32.971831
6	782c37df-f571-4390-bd69-fefdb0e13cf5	30	28	\N	9647	2025-11-13 10:11:26.548
16	aea41626-3127-4b2e-9103-d3f07855a3f3	6	33	\N	6	2025-12-08 09:01:02.182491
17	f64b9331-bbcd-4fdf-a8c7-5b62433dcce5	1	100	\N	1	2025-12-16 04:27:57.444732
\.


--
-- Data for Name: user_streaks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_streaks (id, user_id, streak_days) FROM stdin;
11	1f1956c4-8770-4411-a450-4a415cd2c9fa	12
12	782c37df-f571-4390-bd69-fefdb0e13cf5	7
\.


--
-- Data for Name: user_subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_subscriptions (id, user_id, plan_id, started_at, expires_at, status, metadata) FROM stdin;
42f46ba0-0c51-4937-b83f-571a667f7237	1f1956c4-8770-4411-a450-4a415cd2c9fa	1	2025-11-18 08:13:54.894+00	2025-12-18 08:13:54.651+00	expired	\N
c5de1ffa-0d6e-4c2a-b0f5-26962b674b9b	1f1956c4-8770-4411-a450-4a415cd2c9fa	1	2025-11-18 08:15:42.44+00	2025-12-18 08:15:42.17+00	expired	\N
e668d33d-00d1-4ff3-822f-81e182259ce0	1f1956c4-8770-4411-a450-4a415cd2c9fa	2	2025-11-18 08:15:50.81+00	2026-11-18 08:15:50.547+00	expired	\N
adc499b6-6111-476e-9c0c-e3d57cafc8eb	1f1956c4-8770-4411-a450-4a415cd2c9fa	1	2025-11-18 08:16:09.474+00	2025-12-18 08:16:09.211+00	expired	\N
f82075d1-cf5e-494c-9a02-f849ba01b7bd	1f1956c4-8770-4411-a450-4a415cd2c9fa	2	2025-11-18 08:23:20.276+00	2026-11-18 08:23:19.977+00	expired	\N
dfa6e89d-e044-49b2-a762-6c71380080db	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-11-20 05:09:16.707+00	2026-11-20 05:09:16.471+00	expired	\N
d7f7b0d5-adc3-4bbf-b129-b5eb337cc94c	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-17 10:25:36.762+00	2026-12-17 10:25:36.586+00	expired	\N
daa869f5-70aa-46a1-b43c-c4e04af73fda	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-11-20 08:15:39.458+00	2026-11-20 08:15:39.198+00	expired	\N
68d62057-21b1-4abf-a0b2-53a241eb59b9	782c37df-f571-4390-bd69-fefdb0e13cf5	1	2025-11-29 09:05:11.129+00	2025-12-29 09:05:10.913+00	canceled	\N
5f05ac9e-2a2f-45dc-8dde-ac91a4580bc0	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-11-29 09:21:22.101+00	2026-11-29 09:21:21.905+00	expired	\N
e4a926fe-cadb-4443-8eec-e0a85a1520ef	782c37df-f571-4390-bd69-fefdb0e13cf5	1	2025-11-29 09:21:33.138+00	2025-12-29 09:21:32.958+00	expired	\N
55d919f3-a6b1-4bb4-91bb-4e06c49e2f08	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-11-29 09:21:41.176+00	2026-11-29 09:21:40.98+00	expired	\N
691afc3a-b506-4390-b7a4-351dd6088d51	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-03 05:13:32.651+00	2026-12-03 05:13:32.465+00	expired	\N
82ce393d-3d16-4fd8-b3b7-8454007e6fff	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-17 11:28:55.43+00	2026-01-17 11:28:55.248+00	expired	\N
4e8a2c6b-f2ea-4152-b383-405ef196991e	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-17 11:36:24.389+00	2026-12-17 11:36:24.216+00	expired	\N
190dfb41-e774-416a-8576-6e3acc32e99b	782c37df-f571-4390-bd69-fefdb0e13cf5	1	2025-11-20 05:13:04.611+00	2025-12-20 05:13:04.31+00	expired	\N
2e40f80c-1ad9-4f65-ad8c-86f92a446670	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-03 05:13:35.145+00	2026-12-03 05:13:34.966+00	expired	\N
0e47f349-e58e-4776-8c92-37ca1507d7a8	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-03 05:19:32.82+00	2026-12-03 05:19:32.639+00	canceled	\N
77b16740-b76f-4e72-ae19-077a56aac48d	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-03 05:18:49.097+00	2026-12-03 05:18:48.915+00	canceled	\N
b0f3287b-ab0a-4560-a175-e46db56100a0	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-03 13:43:28.267+00	2026-01-03 13:43:27.961+00	canceled	\N
e1af9ebc-2184-430d-99c3-96ea1685da50	1f1956c4-8770-4411-a450-4a415cd2c9fa	1	2025-11-18 08:29:11.794+00	2025-12-18 08:29:11.606+00	canceled	\N
05d2e918-633d-4961-8d21-6a32f53d17f6	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-04 03:58:38.852+00	2026-12-04 03:58:38.438+00	canceled	\N
0c602842-3f4f-4926-8782-44e065c3dff5	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-04 13:58:19.151+00	2026-12-04 13:58:18.929+00	canceled	\N
931f90ec-63b4-458e-964e-a634ff2abaa6	782c37df-f571-4390-bd69-fefdb0e13cf5	1	2025-12-04 11:51:59.425+00	2026-01-04 11:51:59.017+00	canceled	\N
643de2d6-668d-4a5d-804b-07da199fee92	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-08 08:17:35.158+00	2026-01-08 08:17:34.96+00	canceled	\N
4f238c2a-9046-4736-bab2-45aa9ca3065a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-17 09:52:22.907+00	2026-12-17 09:52:22.718+00	canceled	\N
f0de7718-88cf-4a31-849c-42389917ec5d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-17 10:01:38.052+00	2026-12-17 10:01:37.872+00	expired	\N
d12089de-6e7c-4948-88b7-0b5448adfdcd	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-17 10:04:34.433+00	2026-01-17 10:04:34.215+00	expired	\N
c34e7086-49b8-426c-9c70-4f004c077d4f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-17 10:05:35.852+00	2026-12-17 10:05:35.612+00	expired	\N
0730a8ba-af88-42e9-87cd-41fd9b538416	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-17 10:06:32.157+00	2026-01-17 10:06:31.914+00	expired	\N
69391d2e-e2f3-4006-be7f-d9f0c6d5ace0	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-17 10:07:13.752+00	2026-12-17 10:07:13.563+00	expired	\N
726f5e13-9bdb-474d-a0b4-471bdc34a4c9	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-17 10:11:02.09+00	2026-01-17 10:11:01.884+00	expired	\N
bc260c61-cde5-4fc5-a9ba-b5c5a01a7d50	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-17 10:11:03.414+00	2026-01-17 10:11:03.189+00	expired	\N
bae89301-04a9-4717-8279-c7c07cbde70b	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-17 10:12:01.76+00	2026-12-17 10:12:01.58+00	expired	\N
deb29873-7712-405c-8d99-ed7825ea903d	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-17 10:21:51.886+00	2026-01-17 10:21:51.706+00	expired	\N
00b2f229-6a85-4f3f-ad87-f99f6d6cba97	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-17 11:53:02.601+00	2026-01-17 11:53:02.347+00	expired	\N
4261d619-7216-4b2d-85ee-f7f8f9f46f6c	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-17 11:56:45.61+00	2026-12-17 11:56:45.432+00	expired	\N
8968f9a7-a3e4-4dac-a5fb-224e3fc1af0b	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-18 03:28:12.852+00	2026-01-18 03:28:12.672+00	expired	\N
fd0f313c-abd6-4cf0-bd34-79ccc4bb4d6b	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-18 03:45:39.748+00	2026-12-18 03:45:39.564+00	expired	\N
b7ba73d6-df69-44b0-b487-383d98a0ed49	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-18 03:51:02.092+00	2026-01-18 03:51:01.917+00	expired	\N
d1dd2ea8-2879-4841-a375-a6b158472636	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-18 03:53:08.619+00	2026-12-18 03:53:08.408+00	expired	\N
7d22b115-0669-4e91-a89b-94a6a8c1c6d0	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-18 04:05:08.86+00	2026-01-18 04:05:08.666+00	expired	\N
bc1000c4-c95e-4b16-8317-be7da97ccb69	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-18 04:07:27.817+00	2026-12-18 04:07:27.638+00	expired	\N
e4aed990-0ea5-4f2e-afe5-96bc4c55a746	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-18 04:07:58.55+00	2026-01-18 04:07:58.369+00	expired	\N
9875b656-21de-4849-b2d5-3dbca7c63e6f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-18 04:10:05.493+00	2026-12-18 04:10:05.291+00	expired	\N
11cc2bf4-f836-41d0-a483-90056ccca6b4	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-18 04:22:23.272+00	2026-01-18 04:22:23.076+00	expired	\N
095b6d1a-aad7-49a2-81af-3d2587e8e68a	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-18 04:23:05.191+00	2026-12-18 04:23:05.003+00	expired	\N
67c6b784-0b57-4148-9816-683b62f8a5da	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-18 04:31:55.239+00	2026-01-18 04:31:55.067+00	expired	\N
369f6133-8f81-42e2-ac34-15fa13f15c28	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-06 08:43:30.156+00	2026-12-06 08:43:29.697+00	expired	\N
8ff03b43-3445-48d6-b8d8-6d515635caa2	782c37df-f571-4390-bd69-fefdb0e13cf5	1	2025-12-18 04:41:01.497+00	2026-01-18 04:41:01.318+00	expired	\N
fb7bef9a-e53a-4924-9c38-01b629d8b394	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-18 04:45:26.031+00	2026-12-18 04:45:25.858+00	expired	\N
cfb29e7e-7cd2-4519-b3b1-abe0632c7e1f	782c37df-f571-4390-bd69-fefdb0e13cf5	1	2025-12-18 04:49:42.066+00	2026-01-18 04:49:41.896+00	expired	\N
27a6df46-10ef-4de9-a800-9cb431d13bb8	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-18 04:55:16.311+00	2026-12-18 04:55:16.139+00	expired	\N
25282cf1-4c38-42cd-9ab2-2f3663551521	782c37df-f571-4390-bd69-fefdb0e13cf5	1	2025-12-18 04:59:41.556+00	2026-01-18 04:59:41.377+00	expired	\N
05ed98d1-7a5e-4b38-860a-c24ba2b93df3	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-18 05:23:44.645+00	2026-12-18 05:23:44.47+00	expired	\N
2114a914-eccc-4c4f-8681-f736ad7cdb33	782c37df-f571-4390-bd69-fefdb0e13cf5	1	2025-12-18 05:30:36.001+00	2026-01-18 05:30:35.828+00	expired	\N
214c3d33-df84-43f1-840f-e6dba86cb71c	782c37df-f571-4390-bd69-fefdb0e13cf5	2	2025-12-18 05:32:20.466+00	2026-12-18 05:32:20.294+00	active	\N
55e464b7-1c0e-44b9-a65b-4268a2b28715	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-18 04:38:03.857+00	2026-12-18 04:38:03.685+00	expired	\N
fd926714-bb23-4429-9cd7-5ccc161e40a6	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-20 03:51:21.816+00	2026-01-20 03:51:21.634+00	canceled	\N
056d0daa-149e-4b4c-9825-31285f161f73	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-22 04:46:56.488+00	2026-01-22 04:46:56.286+00	canceled	\N
67919bc7-1063-4302-8376-c26dc31f64b2	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-29 08:36:07.858+00	2026-12-29 08:36:07.68+00	expired	\N
63081c59-c2ca-497f-b608-212cc9825043	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-29 08:46:11.252+00	2026-01-29 08:46:11.085+00	expired	\N
76a8f6ad-93db-4e2b-a5bc-53e2c1341191	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-29 08:49:30.29+00	2026-12-29 08:49:30.123+00	expired	\N
8966bfa4-4f26-46bd-b250-b1c6dccc6d2f	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-29 08:51:34.686+00	2026-01-29 08:51:34.51+00	expired	\N
ed9017a7-3c1e-4ed6-aeee-19235eaaebf2	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2025-12-29 08:51:45.818+00	2026-12-29 08:51:45.617+00	canceled	\N
96981d2d-af2e-4940-abc3-9522747b1504	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2025-12-30 05:08:16.785+00	2026-01-30 05:08:16.58+00	expired	\N
232d5b4b-4ff8-410c-8e9f-56f49bed9924	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2026-01-07 03:52:54.26+00	2027-01-07 03:52:53.887+00	expired	\N
60b050e3-6481-4a3f-aeb6-417389ca4f66	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	1	2026-01-07 03:55:03.839+00	2026-02-07 03:55:03.52+00	expired	\N
e0284462-5c67-491e-892e-017ace875fa3	7e9011b6-a3c8-4c9b-8af6-5050baf0eafb	2	2026-01-07 03:58:18.642+00	2027-01-07 03:58:18.339+00	canceled	\N
\.


--
-- Data for Name: users_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users_metadata (id, name, created_at) FROM stdin;
\.


--
-- Data for Name: watermark_jobs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.watermark_jobs (id, book_id, status, error_message, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: writing_feedback; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.writing_feedback (id, order_id, user_id, writer_name, message, created_at, user_name, sender, read_by_admin) FROM stdin;
\.


--
-- Data for Name: writing_orders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.writing_orders (id, user_id, title, type, subject_area, academic_level, pages, deadline, status, progress, total_price, created_at, updated_at, author_id, accepted_at, completed_at, notes_url, rejection_reason, final_text, rejected_at, user_name, attachments_url, instructions, paid_at, payment_success, payment_status, order_temp_id, additional_notes, updated_by, updated_by_name, user_updated_at, user_updated_notes, admin_updated_at, admin_updated_by) FROM stdin;
\.


--
-- Data for Name: writing_services; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.writing_services (id, name, description, turnaround, base_price, created_at) FROM stdin;
1	Research Paper	Comprehensive research papers with citations	7-14 days	49.00	2025-11-05 08:17:13.097656
2	Essay Writing	Academic essays on any topic	3-7 days	29.00	2025-11-05 08:17:13.097656
3	Dissertation	Full dissertation writing support	30-90 days	299.00	2025-11-05 08:17:13.097656
4	Thesis Writing	Master's and PhD thesis assistance	14-60 days	199.00	2025-11-05 08:17:13.097656
5	Literature Review	Detailed literature reviews	5-10 days	79.00	2025-11-05 08:17:13.097656
6	Editing & Proofreading	Professional editing services	1-3 days	19.00	2025-11-05 08:17:13.097656
\.


--
-- Name: activity_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.activity_log_id_seq', 850, true);


--
-- Name: downloaded_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.downloaded_notes_id_seq', 3, true);


--
-- Name: drm_devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.drm_devices_id_seq', 810, true);


--
-- Name: exams_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.exams_id_seq', 21, true);


--
-- Name: folders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.folders_id_seq', 1, false);


--
-- Name: job_requirements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.job_requirements_id_seq', 21, true);


--
-- Name: jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.jobs_id_seq', 7, true);


--
-- Name: mock_attempts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.mock_attempts_id_seq', 184, true);


--
-- Name: mock_test_questions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.mock_test_questions_id_seq', 88, true);


--
-- Name: mock_tests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.mock_tests_id_seq', 48, true);


--
-- Name: notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notes_id_seq', 74, true);


--
-- Name: revenue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.revenue_id_seq', 550, true);


--
-- Name: saved_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.saved_jobs_id_seq', 1, false);


--
-- Name: study_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.study_notes_id_seq', 43, true);


--
-- Name: study_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.study_sessions_id_seq', 58, true);


--
-- Name: subjects_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.subjects_id_seq', 72, true);


--
-- Name: submissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.submissions_id_seq', 2, true);


--
-- Name: subscription_plans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.subscription_plans_id_seq', 2, true);


--
-- Name: subscriptions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.subscriptions_id_seq', 84, true);


--
-- Name: test_attempts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.test_attempts_id_seq', 2, true);


--
-- Name: test_results_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.test_results_id_seq', 1, false);


--
-- Name: user_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_activity_id_seq', 14, true);


--
-- Name: user_books_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_books_id_seq', 63, true);


--
-- Name: user_devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_devices_id_seq', 1, false);


--
-- Name: user_library_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_library_id_seq', 108, true);


--
-- Name: user_notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_notifications_id_seq', 2169, true);


--
-- Name: user_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_sessions_id_seq', 387, true);


--
-- Name: user_stats_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_stats_id_seq', 18, true);


--
-- Name: user_streaks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_streaks_id_seq', 12, true);


--
-- Name: watermark_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.watermark_jobs_id_seq', 1, false);


--
-- Name: writing_feedback_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.writing_feedback_id_seq', 11, true);


--
-- Name: writing_orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.writing_orders_id_seq', 49, true);


--
-- Name: writing_services_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.writing_services_id_seq', 6, true);


--
-- Name: activity_log activity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_log
    ADD CONSTRAINT activity_log_pkey PRIMARY KEY (id);


--
-- Name: ai_activity_log ai_activity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_activity_log
    ADD CONSTRAINT ai_activity_log_pkey PRIMARY KEY (id);


--
-- Name: ai_settings ai_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_settings
    ADD CONSTRAINT ai_settings_pkey PRIMARY KEY (id);


--
-- Name: backups backups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backups
    ADD CONSTRAINT backups_pkey PRIMARY KEY (id);


--
-- Name: book_sales book_sales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.book_sales
    ADD CONSTRAINT book_sales_pkey PRIMARY KEY (id);


--
-- Name: book_views book_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.book_views
    ADD CONSTRAINT book_views_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);


--
-- Name: collection_books collection_books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_books
    ADD CONSTRAINT collection_books_pkey PRIMARY KEY (id);


--
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);


--
-- Name: current_affairs current_affairs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.current_affairs
    ADD CONSTRAINT current_affairs_pkey PRIMARY KEY (id);


--
-- Name: current_affairs_views current_affairs_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.current_affairs_views
    ADD CONSTRAINT current_affairs_views_pkey PRIMARY KEY (id);


--
-- Name: current_affairs_views current_affairs_views_user_id_article_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.current_affairs_views
    ADD CONSTRAINT current_affairs_views_user_id_article_id_key UNIQUE (user_id, article_id);


--
-- Name: downloaded_notes downloaded_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downloaded_notes
    ADD CONSTRAINT downloaded_notes_pkey PRIMARY KEY (id);


--
-- Name: drm_access_logs drm_access_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drm_access_logs
    ADD CONSTRAINT drm_access_logs_pkey PRIMARY KEY (id);


--
-- Name: drm_devices drm_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drm_devices
    ADD CONSTRAINT drm_devices_pkey PRIMARY KEY (id);


--
-- Name: drm_devices drm_devices_user_device_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drm_devices
    ADD CONSTRAINT drm_devices_user_device_unique UNIQUE (user_id, device_id);


--
-- Name: drm_settings drm_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drm_settings
    ADD CONSTRAINT drm_settings_pkey PRIMARY KEY (id);


--
-- Name: ebook_ratings ebook_ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebook_ratings
    ADD CONSTRAINT ebook_ratings_pkey PRIMARY KEY (id);


--
-- Name: ebook_ratings ebook_ratings_user_id_ebook_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebook_ratings
    ADD CONSTRAINT ebook_ratings_user_id_ebook_id_key UNIQUE (user_id, ebook_id);


--
-- Name: ebooks ebooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebooks
    ADD CONSTRAINT ebooks_pkey PRIMARY KEY (id);


--
-- Name: exams exams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exams
    ADD CONSTRAINT exams_pkey PRIMARY KEY (id);


--
-- Name: folders folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_pkey PRIMARY KEY (id);


--
-- Name: highlights highlights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.highlights
    ADD CONSTRAINT highlights_pkey PRIMARY KEY (id);


--
-- Name: integrations integrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations
    ADD CONSTRAINT integrations_pkey PRIMARY KEY (id);


--
-- Name: interview_materials interview_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_materials
    ADD CONSTRAINT interview_materials_pkey PRIMARY KEY (id);


--
-- Name: job_requirements job_requirements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_requirements
    ADD CONSTRAINT job_requirements_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: mock_answers mock_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_answers
    ADD CONSTRAINT mock_answers_pkey PRIMARY KEY (attempt_id, question_id);


--
-- Name: mock_attempts mock_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_attempts
    ADD CONSTRAINT mock_attempts_pkey PRIMARY KEY (id);


--
-- Name: mock_leaderboard mock_leaderboard_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_leaderboard
    ADD CONSTRAINT mock_leaderboard_pkey PRIMARY KEY (user_id);


--
-- Name: mock_test_questions mock_test_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_test_questions
    ADD CONSTRAINT mock_test_questions_pkey PRIMARY KEY (id);


--
-- Name: mock_tests mock_tests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_tests
    ADD CONSTRAINT mock_tests_pkey PRIMARY KEY (id);


--
-- Name: notes_highlights notes_highlights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_highlights
    ADD CONSTRAINT notes_highlights_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: notes_purchase notes_purchase_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_purchase
    ADD CONSTRAINT notes_purchase_pkey PRIMARY KEY (id);


--
-- Name: notes_read_history notes_read_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_read_history
    ADD CONSTRAINT notes_read_history_pkey PRIMARY KEY (id);


--
-- Name: notes_read_history notes_read_history_user_note_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_read_history
    ADD CONSTRAINT notes_read_history_user_note_unique UNIQUE (user_id, note_id);


--
-- Name: notification_drafts notification_drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_drafts
    ADD CONSTRAINT notification_drafts_pkey PRIMARY KEY (id);


--
-- Name: notification_logs notification_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_logs
    ADD CONSTRAINT notification_logs_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payments_transactions payments_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments_transactions
    ADD CONSTRAINT payments_transactions_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: purchases purchases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT purchases_pkey PRIMARY KEY (id);


--
-- Name: purchases purchases_unique_user_book; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT purchases_unique_user_book UNIQUE (user_id, book_id);


--
-- Name: pyq_papers pyq_papers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pyq_papers
    ADD CONSTRAINT pyq_papers_pkey PRIMARY KEY (id);


--
-- Name: pyq_subjects pyq_subjects_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pyq_subjects
    ADD CONSTRAINT pyq_subjects_name_key UNIQUE (name);


--
-- Name: pyq_subjects pyq_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pyq_subjects
    ADD CONSTRAINT pyq_subjects_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: revenue revenue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revenue
    ADD CONSTRAINT revenue_pkey PRIMARY KEY (id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: saved_jobs saved_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_jobs
    ADD CONSTRAINT saved_jobs_pkey PRIMARY KEY (id);


--
-- Name: saved_jobs saved_jobs_user_id_job_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_jobs
    ADD CONSTRAINT saved_jobs_user_id_job_id_key UNIQUE (user_id, job_id);


--
-- Name: study_notes study_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_notes
    ADD CONSTRAINT study_notes_pkey PRIMARY KEY (id);


--
-- Name: study_sessions study_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_sessions
    ADD CONSTRAINT study_sessions_pkey PRIMARY KEY (id);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: subjects subjects_value_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_value_key UNIQUE (value);


--
-- Name: subjects subjects_value_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_value_unique UNIQUE (value);


--
-- Name: submissions submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_pkey PRIMARY KEY (id);


--
-- Name: subscription_plans subscription_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_pkey PRIMARY KEY (id);


--
-- Name: subscription_plans subscription_plans_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_slug_key UNIQUE (slug);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: system_settings system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_pkey PRIMARY KEY (id);


--
-- Name: test_attempts test_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_pkey PRIMARY KEY (id);


--
-- Name: test_results test_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_results
    ADD CONSTRAINT test_results_pkey PRIMARY KEY (id);


--
-- Name: collection_books unique_collection_book; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_books
    ADD CONSTRAINT unique_collection_book UNIQUE (collection_id, book_id);


--
-- Name: subjects unique_value; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT unique_value UNIQUE (value);


--
-- Name: user_activity user_activity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activity
    ADD CONSTRAINT user_activity_pkey PRIMARY KEY (id);


--
-- Name: user_books user_books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_books
    ADD CONSTRAINT user_books_pkey PRIMARY KEY (id);


--
-- Name: user_cart user_cart_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_cart
    ADD CONSTRAINT user_cart_pkey PRIMARY KEY (id);


--
-- Name: user_devices user_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_pkey PRIMARY KEY (id);


--
-- Name: user_library user_library_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_library
    ADD CONSTRAINT user_library_pkey PRIMARY KEY (id);


--
-- Name: user_notifications user_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notifications
    ADD CONSTRAINT user_notifications_pkey PRIMARY KEY (id);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: user_profiles user_profiles_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_email_key UNIQUE (email);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: user_security user_security_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_security
    ADD CONSTRAINT user_security_pkey PRIMARY KEY (user_id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_stats user_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_pkey PRIMARY KEY (id);


--
-- Name: user_stats user_stats_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_user_id_key UNIQUE (user_id);


--
-- Name: user_streaks user_streaks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_streaks
    ADD CONSTRAINT user_streaks_pkey PRIMARY KEY (id);


--
-- Name: user_subscriptions user_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: users_metadata users_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_metadata
    ADD CONSTRAINT users_metadata_pkey PRIMARY KEY (id);


--
-- Name: watermark_jobs watermark_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watermark_jobs
    ADD CONSTRAINT watermark_jobs_pkey PRIMARY KEY (id);


--
-- Name: writing_feedback writing_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_feedback
    ADD CONSTRAINT writing_feedback_pkey PRIMARY KEY (id);


--
-- Name: writing_orders writing_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_orders
    ADD CONSTRAINT writing_orders_pkey PRIMARY KEY (id);


--
-- Name: writing_services writing_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_services
    ADD CONSTRAINT writing_services_pkey PRIMARY KEY (id);


--
-- Name: drm_access_logs_view_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX drm_access_logs_view_created_at_idx ON public.drm_access_logs_view USING btree (created_at DESC);


--
-- Name: idx_attempt_user_test; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attempt_user_test ON public.mock_attempts USING btree (user_id, test_id);


--
-- Name: idx_book_sales_book_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_book_sales_book_id ON public.book_sales USING btree (book_id);


--
-- Name: idx_downloaded_notes_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_downloaded_notes_note_id ON public.downloaded_notes USING btree (note_id);


--
-- Name: idx_downloaded_notes_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_downloaded_notes_user_id ON public.downloaded_notes USING btree (user_id);


--
-- Name: idx_drm_access_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drm_access_logs_created_at ON public.drm_access_logs USING btree (created_at DESC);


--
-- Name: idx_drm_logs_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drm_logs_time ON public.drm_access_logs USING btree (created_at DESC);


--
-- Name: idx_ebooks_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ebooks_embedding ON public.ebooks USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: idx_exams_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_exams_subject_id ON public.exams USING btree (subject_id);


--
-- Name: idx_interview_materials_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interview_materials_category ON public.interview_materials USING btree (category);


--
-- Name: idx_interview_materials_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interview_materials_title ON public.interview_materials USING gin (to_tsvector('english'::regconfig, title));


--
-- Name: idx_mock_attempts_test_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mock_attempts_test_id ON public.mock_attempts USING btree (test_id);


--
-- Name: idx_notes_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes_embedding ON public.notes USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: idx_notes_read_history_note; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes_read_history_note ON public.notes_read_history USING btree (note_id);


--
-- Name: idx_notes_read_history_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes_read_history_note_id ON public.notes_read_history USING btree (note_id);


--
-- Name: idx_notes_read_history_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes_read_history_user ON public.notes_read_history USING btree (user_id);


--
-- Name: idx_notes_read_history_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes_read_history_user_id ON public.notes_read_history USING btree (user_id);


--
-- Name: idx_purchases_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchases_user_id ON public.purchases USING btree (user_id);


--
-- Name: idx_study_notes_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_study_notes_subject_id ON public.study_notes USING btree (subject_id);


--
-- Name: idx_submissions_exam_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_submissions_exam_id ON public.submissions USING btree (exam_id);


--
-- Name: idx_subscriptions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subscriptions_status ON public.subscriptions USING btree (status);


--
-- Name: idx_subscriptions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subscriptions_user ON public.subscriptions USING btree (user_id);


--
-- Name: idx_user_devices_fp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_devices_fp ON public.user_devices USING btree (fingerprint);


--
-- Name: idx_user_devices_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_devices_uid ON public.user_devices USING btree (user_id);


--
-- Name: idx_user_library_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_library_completed_at ON public.user_library USING btree (user_id, completed_at);


--
-- Name: idx_user_notifications_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_notifications_user_id ON public.user_notifications USING btree (user_id);


--
-- Name: idx_watermark_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_watermark_status ON public.watermark_jobs USING btree (status);


--
-- Name: mock_leaderboard_score_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mock_leaderboard_score_idx ON public.mock_leaderboard USING btree (average_score DESC);


--
-- Name: notes_cached_preview_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notes_cached_preview_idx ON public.notes USING btree (id);


--
-- Name: notes_purchase_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX notes_purchase_unique ON public.notes_purchase USING btree (user_id, note_id);


--
-- Name: uniq_user_device; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_user_device ON public.user_sessions USING btree (user_id, device_id);


--
-- Name: user_cart_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_cart_unique ON public.user_cart USING btree (user_id, COALESCE((book_id)::text, (note_id)::text));


--
-- Name: payments_transactions trg_revenue_entry; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_revenue_entry AFTER INSERT ON public.payments_transactions FOR EACH ROW EXECUTE FUNCTION public.add_revenue_entry();


--
-- Name: ai_activity_log ai_activity_log_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_activity_log
    ADD CONSTRAINT ai_activity_log_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES auth.users(id);


--
-- Name: book_sales book_sales_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.book_sales
    ADD CONSTRAINT book_sales_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: book_views book_views_book_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.book_views
    ADD CONSTRAINT book_views_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.ebooks(id) ON DELETE CASCADE;


--
-- Name: book_views book_views_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.book_views
    ADD CONSTRAINT book_views_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: collection_books collection_books_collection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_books
    ADD CONSTRAINT collection_books_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES public.collections(id) ON DELETE CASCADE;


--
-- Name: downloaded_notes downloaded_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downloaded_notes
    ADD CONSTRAINT downloaded_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(id);


--
-- Name: downloaded_notes downloaded_notes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downloaded_notes
    ADD CONSTRAINT downloaded_notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: ebooks ebooks_category_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebooks
    ADD CONSTRAINT ebooks_category_fk FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: ebooks ebooks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebooks
    ADD CONSTRAINT ebooks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: exams exams_folder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exams
    ADD CONSTRAINT exams_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES public.folders(id) ON DELETE SET NULL;


--
-- Name: exams exams_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exams
    ADD CONSTRAINT exams_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: mock_attempts fk_attempt_test; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_attempts
    ADD CONSTRAINT fk_attempt_test FOREIGN KEY (test_id) REFERENCES public.mock_tests(id) ON DELETE CASCADE;


--
-- Name: mock_attempts fk_attempt_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_attempts
    ADD CONSTRAINT fk_attempt_user FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: book_sales fk_book_sales_book; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.book_sales
    ADD CONSTRAINT fk_book_sales_book FOREIGN KEY (book_id) REFERENCES public.ebooks(id) ON DELETE CASCADE;


--
-- Name: book_sales fk_book_sales_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.book_sales
    ADD CONSTRAINT fk_book_sales_user FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: user_cart fk_cart_note; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_cart
    ADD CONSTRAINT fk_cart_note FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;


--
-- Name: collection_books fk_collection_books_ebooks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collection_books
    ADD CONSTRAINT fk_collection_books_ebooks FOREIGN KEY (book_id) REFERENCES public.ebooks(id);


--
-- Name: ebook_ratings fk_ebook_ratings_ebook; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebook_ratings
    ADD CONSTRAINT fk_ebook_ratings_ebook FOREIGN KEY (ebook_id) REFERENCES public.ebooks(id) ON DELETE CASCADE;


--
-- Name: ebook_ratings fk_ebook_ratings_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebook_ratings
    ADD CONSTRAINT fk_ebook_ratings_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: exams fk_exams_subject; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exams
    ADD CONSTRAINT fk_exams_subject FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE SET NULL;


--
-- Name: mock_test_questions fk_mock_test_questions_test_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_test_questions
    ADD CONSTRAINT fk_mock_test_questions_test_id FOREIGN KEY (test_id) REFERENCES public.mock_tests(id) ON DELETE CASCADE;


--
-- Name: mock_test_questions fk_mocktest_questions; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_test_questions
    ADD CONSTRAINT fk_mocktest_questions FOREIGN KEY (test_id) REFERENCES public.mock_tests(id) ON DELETE CASCADE;


--
-- Name: revenue fk_revenue_payment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revenue
    ADD CONSTRAINT fk_revenue_payment FOREIGN KEY (payment_id) REFERENCES public.payments_transactions(id) ON DELETE SET NULL;


--
-- Name: user_books fk_user_books_book; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_books
    ADD CONSTRAINT fk_user_books_book FOREIGN KEY (book_id) REFERENCES public.ebooks(id) ON DELETE CASCADE;


--
-- Name: user_library fk_user_library_ebooks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_library
    ADD CONSTRAINT fk_user_library_ebooks FOREIGN KEY (book_id) REFERENCES public.ebooks(id) ON DELETE CASCADE;


--
-- Name: job_requirements job_requirements_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_requirements
    ADD CONSTRAINT job_requirements_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: mock_answers mock_answers_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_answers
    ADD CONSTRAINT mock_answers_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.mock_attempts(id) ON DELETE CASCADE;


--
-- Name: mock_answers mock_answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_answers
    ADD CONSTRAINT mock_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.mock_test_questions(id) ON DELETE CASCADE;


--
-- Name: test_attempts mock_attempts_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT mock_attempts_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.mock_tests(id) ON DELETE CASCADE;


--
-- Name: mock_attempts mock_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_attempts
    ADD CONSTRAINT mock_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: mock_leaderboard mock_leaderboard_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_leaderboard
    ADD CONSTRAINT mock_leaderboard_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: mock_test_questions mock_test_questions_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_test_questions
    ADD CONSTRAINT mock_test_questions_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.mock_tests(id) ON DELETE CASCADE;


--
-- Name: mock_tests mock_tests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mock_tests
    ADD CONSTRAINT mock_tests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: notes notes_category_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_category_fk FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: notes_highlights notes_highlights_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_highlights
    ADD CONSTRAINT notes_highlights_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;


--
-- Name: notes_highlights notes_highlights_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_highlights
    ADD CONSTRAINT notes_highlights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: notes_purchase notes_purchase_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_purchase
    ADD CONSTRAINT notes_purchase_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: notes_read_history notes_read_history_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_read_history
    ADD CONSTRAINT notes_read_history_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;


--
-- Name: notes_read_history notes_read_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes_read_history
    ADD CONSTRAINT notes_read_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: notes notes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: payment_methods payment_methods_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: payments_transactions payments_transactions_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments_transactions
    ADD CONSTRAINT payments_transactions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id);


--
-- Name: payments_transactions payments_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments_transactions
    ADD CONSTRAINT payments_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: purchases purchases_book_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT purchases_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.ebooks(id) ON DELETE CASCADE;


--
-- Name: purchases purchases_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT purchases_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: pyq_papers pyq_papers_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pyq_papers
    ADD CONSTRAINT pyq_papers_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.pyq_subjects(id) ON DELETE CASCADE;


--
-- Name: saved_jobs saved_jobs_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_jobs
    ADD CONSTRAINT saved_jobs_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- Name: saved_jobs saved_jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_jobs
    ADD CONSTRAINT saved_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: study_notes study_notes_folder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_notes
    ADD CONSTRAINT study_notes_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES public.folders(id) ON DELETE SET NULL;


--
-- Name: study_notes study_notes_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_notes
    ADD CONSTRAINT study_notes_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE CASCADE;


--
-- Name: study_notes study_notes_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_notes
    ADD CONSTRAINT study_notes_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.profiles(id);


--
-- Name: study_sessions study_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_sessions
    ADD CONSTRAINT study_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: submissions submissions_exam_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES public.exams(id) ON DELETE CASCADE;


--
-- Name: submissions submissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: subscriptions subscriptions_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_user_fk FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: test_attempts test_attempts_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.mock_tests(id) ON DELETE CASCADE;


--
-- Name: test_attempts test_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: test_results test_results_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_results
    ADD CONSTRAINT test_results_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.mock_tests(id);


--
-- Name: test_results test_results_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_results
    ADD CONSTRAINT test_results_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: user_activity user_activity_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activity
    ADD CONSTRAINT user_activity_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: user_books user_books_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_books
    ADD CONSTRAINT user_books_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: user_cart user_cart_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_cart
    ADD CONSTRAINT user_cart_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_library user_library_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_library
    ADD CONSTRAINT user_library_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_security user_security_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_security
    ADD CONSTRAINT user_security_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_stats user_stats_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: user_streaks user_streaks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_streaks
    ADD CONSTRAINT user_streaks_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: user_subscriptions user_subscriptions_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id);


--
-- Name: user_subscriptions user_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: users_metadata users_metadata_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_metadata
    ADD CONSTRAINT users_metadata_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: writing_feedback writing_feedback_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_feedback
    ADD CONSTRAINT writing_feedback_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.writing_orders(id) ON DELETE CASCADE;


--
-- Name: writing_feedback writing_feedback_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_feedback
    ADD CONSTRAINT writing_feedback_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: writing_orders writing_orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.writing_orders
    ADD CONSTRAINT writing_orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles Allow service role to do anything; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role to do anything" ON public.profiles TO service_role USING (true) WITH CHECK (true);


--
-- Name: interview_materials Public can view active materials; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public can view active materials" ON public.interview_materials FOR SELECT USING ((is_active = true));


--
-- Name: profiles TEMP allow all inserts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "TEMP allow all inserts" ON public.profiles FOR INSERT WITH CHECK (true);


--
-- Name: profiles Users can insert their own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: notes_purchase Users can purchase notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can purchase notes" ON public.notes_purchase FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: profiles Users can read their own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read their own profile" ON public.profiles FOR SELECT USING ((auth.uid() = id));


--
-- Name: profiles Users can update their own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING ((auth.uid() = id));


--
-- Name: notes_purchase Users can view their purchased notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their purchased notes" ON public.notes_purchase FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: mock_tests admin delete mock tests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin delete mock tests" ON public.mock_tests FOR DELETE TO authenticated USING (((auth.jwt() ->> 'role'::text) = 'admin'::text));


--
-- Name: exams admin_manage_exams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_manage_exams ON public.exams TO authenticated USING (((auth.jwt() ->> 'role'::text) = 'admin'::text)) WITH CHECK (((auth.jwt() ->> 'role'::text) = 'admin'::text));


--
-- Name: writing_feedback admin_read_all_feedback; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_read_all_feedback ON public.writing_feedback FOR SELECT USING (true);


--
-- Name: submissions admin_read_all_submissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_read_all_submissions ON public.submissions FOR SELECT TO authenticated USING (((auth.jwt() ->> 'role'::text) = 'admin'::text));


--
-- Name: exams allow_read_exams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_read_exams ON public.exams FOR SELECT TO authenticated USING (true);


--
-- Name: ebooks allow_select_ebooks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select_ebooks ON public.ebooks FOR SELECT TO authenticated USING (true);


--
-- Name: submissions allow_user_insert_submission; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_user_insert_submission ON public.submissions FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: submissions allow_user_read_own_submissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_user_read_own_submissions ON public.submissions FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: book_sales dashboard_seed_book_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dashboard_seed_book_policy ON public.book_sales FOR INSERT TO service_role WITH CHECK (true);


--
-- Name: subscriptions dashboard_seed_sub_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dashboard_seed_sub_policy ON public.subscriptions FOR INSERT TO service_role WITH CHECK (true);


--
-- Name: ebooks ebooks_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ebooks_public_read ON public.ebooks FOR SELECT USING (true);


--
-- Name: ebooks ebooks_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ebooks_select_all ON public.ebooks FOR SELECT USING (true);


--
-- Name: ebooks ebooks_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ebooks_service_role_all ON public.ebooks TO service_role USING (true) WITH CHECK (true);


--
-- Name: exams; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;

--
-- Name: notes insert_notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY insert_notes ON public.notes FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: interview_materials; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.interview_materials ENABLE ROW LEVEL SECURITY;

--
-- Name: mock_tests mock_tests_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mock_tests_public_read ON public.mock_tests FOR SELECT USING (true);


--
-- Name: mock_tests mock_tests_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mock_tests_service_role_all ON public.mock_tests TO service_role USING (true) WITH CHECK (true);


--
-- Name: mock_tests mock_tests_user_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mock_tests_user_delete ON public.mock_tests FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: mock_tests mock_tests_user_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mock_tests_user_insert ON public.mock_tests FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: mock_tests mock_tests_user_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mock_tests_user_update ON public.mock_tests FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

--
-- Name: notes notes_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_public_read ON public.notes FOR SELECT USING (true);


--
-- Name: notes_purchase; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notes_purchase ENABLE ROW LEVEL SECURITY;

--
-- Name: notes notes_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_service_role_all ON public.notes TO service_role USING (true) WITH CHECK (true);


--
-- Name: notes notes_user_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_user_delete ON public.notes FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: notes notes_user_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_user_insert ON public.notes FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: notes notes_user_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notes_user_update ON public.notes FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: notes select_notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY select_notes ON public.notes FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: subjects service role full access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "service role full access" ON public.subjects TO service_role USING (true) WITH CHECK (true);


--
-- Name: notes service role insert notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "service role insert notes" ON public.notes FOR INSERT TO service_role WITH CHECK (true);


--
-- Name: notes service role select notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "service role select notes" ON public.notes FOR SELECT TO service_role USING (true);


--
-- Name: exams service_full_access_exams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_full_access_exams ON public.exams USING ((auth.role() = 'service_role'::text)) WITH CHECK ((auth.role() = 'service_role'::text));


--
-- Name: submissions service_full_access_submissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_full_access_submissions ON public.submissions USING ((auth.role() = 'service_role'::text)) WITH CHECK ((auth.role() = 'service_role'::text));


--
-- Name: profiles service_role_full_access_profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_full_access_profiles ON public.profiles TO service_role USING (true) WITH CHECK (true);


--
-- Name: study_notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.study_notes ENABLE ROW LEVEL SECURITY;

--
-- Name: study_notes study_notes_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY study_notes_admin_write ON public.study_notes USING (((auth.role() = 'service_role'::text) OR ((auth.jwt() ->> 'role'::text) = 'admin'::text))) WITH CHECK (((auth.role() = 'service_role'::text) OR ((auth.jwt() ->> 'role'::text) = 'admin'::text)));


--
-- Name: study_notes study_notes_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY study_notes_read ON public.study_notes FOR SELECT TO authenticated USING (true);


--
-- Name: subjects subjects authenticated read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "subjects authenticated read" ON public.subjects FOR SELECT TO authenticated USING (true);


--
-- Name: subjects subjects service-role full; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "subjects service-role full" ON public.subjects TO service_role USING (true) WITH CHECK (true);


--
-- Name: submissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles user_insert_own_profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_insert_own_profile ON public.profiles FOR INSERT TO authenticated WITH CHECK ((auth.uid() = id));


--
-- Name: user_library; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_library ENABLE ROW LEVEL SECURITY;

--
-- Name: user_library user_library_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_library_delete ON public.user_library FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: user_library user_library_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_library_insert ON public.user_library FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_library user_library_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_library_select ON public.user_library FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: user_library user_library_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_library_update ON public.user_library FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: profiles user_read_own_profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_read_own_profile ON public.profiles FOR SELECT TO authenticated USING ((auth.uid() = id));


--
-- Name: profiles user_update_own_profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_update_own_profile ON public.profiles FOR UPDATE TO authenticated USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: drm_access_logs_view; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: -
--

REFRESH MATERIALIZED VIEW public.drm_access_logs_view;


--
-- PostgreSQL database dump complete
--

\unrestrict AgtDUb0ibQ7nghHEBXhGS94BX4wsTKNqcwnNAOksvwuLD1jlGSOpOHaNvzIIpiA

