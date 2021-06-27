-- Main tuples table
DROP TABLE IF EXISTS tuples;

CREATE TABLE tuples (
  object text NOT NULL,
  object_namespace text NOT NULL,
  relation text NOT NULL,
  subject text NOT NULL,
  subject_namespace text, -- nullable because only valid if subject set
  subject_relation text -- again only applicable for subject sets
);

-- Test dataset
INSERT INTO tuples (object, object_namespace, relation, subject, subject_namespace, subject_relation) VALUES
    ('/cats', 'videos', 'owner', 'cat lady', NULL, NULL),
    ('/cats', 'videos', 'view', '/cats', 'videos', 'owner'),
    ('/cats/2.mp4', 'videos', 'owner', '/cats', 'videos', 'owner'),
    ('/cats/2.mp4', 'videos', 'view', '/cats', 'videos', 'owner'),
    ('/cats/1.mp4', 'videos', 'view', '*', NULL, NULL),
    ('/cats/1.mp4', 'videos', 'owner', '/cats', 'videos', 'owner'),
    ('/cats/1.mp4', 'videos', 'view', '/cats/1.mp4', 'videos', 'owner');

CREATE OR REPLACE FUNCTION zanzibar_expand (p_relation text, p_object_namespace text, p_object text, p_seen text[] DEFAULT '{}' ::text[])
  RETURNS TABLE (
    r_object_namespace text,
    r_object text,
    r_relation text,
    r_subject text)
  LANGUAGE plpgsql
AS $$
DECLARE
  var_r record;
BEGIN
  FOR var_r IN (
    SELECT
      object,
      object_namespace,
      relation,
      subject,
      subject_namespace,
      subject_relation
    FROM
      tuples
    WHERE
      object_namespace = p_object_namespace
      AND object = p_object
      AND relation = p_relation
    ORDER BY
      subject_relation NULLS FIRST)
    LOOP
      IF array_position(p_seen, var_r.subject) IS NULL THEN
        p_seen := array_append(p_seen, var_r.subject);
        IF var_r.subject_namespace IS NULL AND var_r.subject_relation IS NULL THEN
          r_object_namespace := var_r.object_namespace;
          r_object := var_r.object;
          r_relation := var_r.relation;
          r_subject := var_r.subject;
          RETURN NEXT;
        ELSE
          RETURN QUERY
          SELECT * FROM zanzibar_expand (var_r.subject_relation, var_r.subject_namespace, var_r.subject, p_seen);
        END IF;
      END IF;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION zanzibar_check (p_subject text, p_relation text, p_object_namespace text, p_object text)
  RETURNS boolean
  LANGUAGE plpgsql
AS $$
DECLARE
  var_r record;
  var_b boolean;
BEGIN
  FOR var_r IN (
    SELECT
      object,
      object_namespace,
      relation,
      subject,
      subject_namespace,
      subject_relation
    FROM
      tuples
    WHERE
      object_namespace = p_object_namespace
      AND object = p_object
      AND relation = p_relation
    ORDER BY
      subject_relation NULLS FIRST)
    LOOP
      IF var_r.subject = p_subject THEN
        RETURN TRUE;
      END IF;
      IF var_r.subject_namespace IS NOT NULL AND var_r.subject_relation IS NOT NULL THEN
        EXECUTE 'SELECT zanzibar_check($1, $2, $3, $4)'
        USING p_subject, var_r.subject_relation, var_r.subject_namespace, var_r.subject INTO var_b;
        IF var_b = TRUE THEN
          RETURN TRUE;
        END IF;
      END IF;
      END LOOP;
      RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION zanzibar_enumerate (p_subject text, p_relation text, p_object_namespace text)
  RETURNS TABLE (
    r_object_namespace text,
    r_object text,
    r_relation text,
    r_subject text)
  LANGUAGE plpgsql
AS $$
DECLARE
  var_r record;
BEGIN
    FOR var_r IN (
      SELECT
        object,
        object_namespace,
        relation,
        subject,
        subject_namespace,
        subject_relation
      FROM
        tuples
      WHERE
        subject = p_subject
      ORDER BY
        subject_relation NULLS FIRST)
      LOOP
        IF var_r.object_namespace = p_object_namespace AND var_r.relation = p_relation THEN
          r_object_namespace := var_r.object_namespace;
          r_object := var_r.object;
          r_relation := var_r.relation;
          r_subject := var_r.subject;
          RETURN NEXT;
        ELSE
          RETURN QUERY SELECT * FROM zanzibar_enumerate (var_r.object, p_relation, p_object_namespace);
        END IF;
      END LOOP;
END;
$$;

SELECT zanzibar_expand('view', 'videos', '/cats/1.mp4');
SELECT zanzibar_check('*', 'view', 'videos', '/cats/1.mp4');
SELECT zanzibar_check('*', 'view', 'videos', '/cats/2.mp4');
SELECT zanzibar_check('cat lady', 'view', 'videos', '/cats/2.mp4');
SELECT zanzibar_enumerate('cat lady', 'owner', 'videos');
