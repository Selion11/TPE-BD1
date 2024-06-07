DROP TABLE IF EXISTS aula_examen;
CREATE TABLE aula_examen (
    nroaula INTEGER NOT NULL,
    fecha_hora TIMESTAMP NOT NULL,
    duracion INTERVAL NOT NULL,
    codmateria VARCHAR(20) NOT NULL,
    confirmado BOOLEAN NOT NULL
);


CREATE OR REPLACE FUNCTION check_overlap()
RETURNS TRIGGER AS $$
DECLARE
    exam_cursor CURSOR FOR
        SELECT fecha_hora, duracion FROM aula_examen 
        WHERE nroaula = NEW.nroaula AND confirmado = TRUE;
    current_fecha_hora TIMESTAMP;
    current_duracion INTERVAL;
    new_end_time TIMESTAMP;
    current_end_time TIMESTAMP;
    overlap BOOLEAN := FALSE;
    exam_count INT;
BEGIN
    SELECT COUNT(*) INTO exam_count FROM aula_examen WHERE nroaula = NEW.nroaula;

    IF exam_count = 0 THEN
        NEW.confirmado := TRUE;
        RETURN NEW;
    END IF;
    
    new_end_time := NEW.fecha_hora + NEW.duracion;
    OPEN exam_cursor;
    LOOP
        FETCH exam_cursor INTO current_fecha_hora, current_duracion;
        EXIT WHEN NOT FOUND;
        current_end_time := current_fecha_hora + current_duracion;
        IF NEW.fecha_hora <= current_end_time AND new_end_time >= current_fecha_hora THEN
            overlap := TRUE;
            EXIT; 
        END IF;
    END LOOP;
    CLOSE exam_cursor;
    IF overlap THEN
        NEW.confirmado := FALSE;
    ELSE
        NEW.confirmado := TRUE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



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

CREATE TRIGGER check_overlap_trigger
BEFORE INSERT ON aula_examen
FOR EACH ROW
EXECUTE FUNCTION check_overlap();

INSERT INTO aula_examen VALUES (10, '10/10/2024 10:00:00','3:00:00','78',FALSE);
SELECT * from aula_examen