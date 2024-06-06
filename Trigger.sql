DROP TABLE IF EXISTS aula_examen;
CREATE TABLE aula_examen (
    nroaula INTEGER NOT NULL,
    fecha_hora TIMESTAMP NOT NULL,
    duracion INTERVAL NOT NULL,
    codmateria VARCHAR(20) NOT NULL,
    confirmado BOOLEAN NOT NULL
);


CREATE OR REPLACE FUNCTION  check_fecha() RETURNS TRIGGER AS $$
DECLARE 
        end_time timestamp;
BEGIN
        end_time = NEW.fecha_hora + NEW.duracion;
        IF DATE(NEW.fecha_hora) <> DATE(end_time) THEN
              RAISE EXCEPTION 'La fecha de finalizacion es distinta a la fecha de inicio';
        END IF;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_fecha_trigger
BEFORE INSERT ON aula_examen
FOR EACH ROW
EXECUTE FUNCTION check_fecha();

INSERT INTO aula_examen VALUES (10, '10/10/2024 10:00:00','3:00:00','78',FALSE);
SELECT * from aula_examen