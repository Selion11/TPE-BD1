DROP TABLE IF EXISTS aula_examen;
CREATE TABLE aula_examen (
    nroaula INTEGER NOT NULL,
    fecha_hora TIMESTAMP NOT NULL,
    duracion INTERVAL NOT NULL,
    codmateria VARCHAR(20) NOT NULL,
    confirmado BOOLEAN
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
    EXCEPTION
        WHEN others THEN
            NEW.confirmado := FALSE;
            RETURN NEW;
    END;

    IF overlap THEN
        NEW.confirmado := FALSE;
    ELSE
        NEW.confirmado := TRUE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION check_fecha() RETURNS TRIGGER AS $$
DECLARE 
    end_time TIMESTAMP;
BEGIN
    BEGIN
        end_time := NEW.fecha_hora + NEW.duracion;
        IF DATE(NEW.fecha_hora) <> DATE(end_time) THEN
            RAISE EXCEPTION 'La fecha de finalizacion es distinta a la fecha de inicio';
        END IF;
    EXCEPTION
        WHEN others THEN
            NEW.confirmado := FALSE;
            RETURN NEW;
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS analisis_asignaciones(dia_hora TIMESTAMP);
CREATE OR REPLACE FUNCTION analisis_asignaciones(dia_hora TIMESTAMP)
RETURNS TABLE (
    "Variable" VARCHAR(20),
    "Fecha" TIMESTAMP,
    "Horas" INTERVAL,
    "Nro Linea" BIGINT
) AS $$
DECLARE
    tiene_confirmadas BOOLEAN;
    tiene_no_confirmadas BOOLEAN;
    linea_record RECORD;
    nro_linea BIGINT := 0; -- Variable for row number
BEGIN
    -- Check if there are confirmed assignments after the given date and time
    SELECT EXISTS (
        SELECT 1
        FROM aula_examen
        WHERE confirmado = TRUE AND fecha_hora >= dia_hora
    ) INTO tiene_confirmadas;

    -- Check if there are unconfirmed assignments after the given date and time
    SELECT EXISTS (
        SELECT 1
        FROM aula_examen
        WHERE confirmado = FALSE AND fecha_hora >= dia_hora
    ) INTO tiene_no_confirmadas;

    -- Only proceed if there are confirmed or unconfirmed assignments
    IF tiene_confirmadas OR tiene_no_confirmadas THEN
        -- Print the report title
        RAISE NOTICE 'ANALISIS DE ASIGNACIONES';
        RAISE NOTICE '----------------------------------------';

        -- Print column headers
        RAISE NOTICE '%------%------------%-----------%', 'Variable', 'Fecha', 'Horas', 'Nro Linea';

        -- Para las asignaciones confirmadas
        IF tiene_confirmadas THEN
            FOR linea_record IN
                SELECT
                    codmateria AS Variable,
                    DATE_TRUNC('day', fecha_hora) AS Fecha,
                    AVG(duracion) AS Horas
                FROM aula_examen
                WHERE confirmado = TRUE AND fecha_hora >= dia_hora
                GROUP BY codmateria, Fecha
                ORDER BY codmateria, AVG(duracion) DESC
            LOOP
                nro_linea := nro_linea + 1; -- Increment row number
                RAISE NOTICE '%      %         %        %', linea_record.Variable, linea_record.Fecha, linea_record.Horas, nro_linea;
            END LOOP;
        END IF;

        -- Para las asignaciones no confirmadas
        IF tiene_no_confirmadas THEN
            FOR linea_record IN
                SELECT
                    nroaula::VARCHAR AS Variable,
                    fecha_hora AS Fecha,
                    duracion AS Horas
                FROM aula_examen
                WHERE confirmado = FALSE AND fecha_hora >= dia_hora
                ORDER BY nroaula, fecha_hora
            LOOP
                nro_linea := nro_linea + 1; -- Increment row number
                RAISE NOTICE '%      %         %        %', linea_record.Variable, linea_record.Fecha, linea_record.Horas, nro_linea;
            END LOOP;
        END IF;
    ELSE
        RAISE NOTICE 'No hay asignaciones para la fecha y hora ingresadas.';
    END IF;
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


/*INSERT INTO aula_examen VALUES (10, '10/10/2024 10:00:00','3:00:00','78',FALSE);

select * from aula_examen;

SELECT * FROM analisis_asignaciones('2024-06-14 08:00:00');*/
