CREATE TABLE posts (
  id bigserial PRIMARY KEY,
  title text NOT NULL,
  body text NOT NULL,
  views integer NOT NULL,
  inserted_at timestamptz NOT NULL DEFAULT now()
);
