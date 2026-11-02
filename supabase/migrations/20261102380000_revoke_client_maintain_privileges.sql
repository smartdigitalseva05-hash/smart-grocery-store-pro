-- PostgreSQL 17 introduced MAINTAIN. It is not required by browser/API
-- clients; remove it from existing public tables and future postgres-owned
-- public tables. Ordinary DML remains controlled by explicit grants and RLS.
REVOKE MAINTAIN ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE MAINTAIN ON TABLES FROM PUBLIC, anon, authenticated;
