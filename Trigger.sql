/*      Aplicar los conceptos de SQL avanzado (Triggers, PSM) para implementar cosas que NO SE PUEDEN RESOLVER CON LOS METODOS ESTANDAR
//      
//      Se tiene una BD para registrar asignacion de aulas para los examenes.
//      Antes de realizar la asignacion se requiere validar que no haya superposicion de fechas y horarios para el aula en cuestion.

//      Se tiene la tabla aula_examen(nroAula, fecha_hora, duracion, codMateria, confirmado).
//      NroAula tiene numeros, fecha tiene fecha y hora, duracion almacena un intervalo abierto o cerrado, codMateria tiene alfanumericos, confirmado bool.
//      Confirmado se asigna como TRUE si la banda horaria solicitada no esta ocupada. Caso contrario FALSE.

//      Se implementara este procedimiento para una tabla aula_examen que deberan crear de acuerdo a los requerimientos. 

//      Se provee un archivo CSV con informacion para realizar el trabajo. Contiene informacion de los pedidos de asignacion de aulas para diferentes examenes.

//      El CSV tiene: Aula, fecha y hora inicio, intervalo, materia.
//      La fecha de inicio tiene que ser la misma de finalizacion

//      HAY QUE

//      Crear la tabla aula_examen (usar el tipo de dato INTERVAL)
//      Crear un trigger para completar automaticamente la columna confirmado. (No se puede usar el OVERLAPS)
//      Importar los datos y cargar la tabla aula_examen
//      Implementar la funcion para analizar los casos de asignacion exitosa y no exitosa.
//      No modificar el CSV

//      Crear la funcion analisis_asignaciones(dia_hora) que recibe como param una fecha y hora que se toma como fecha base
//      a partir de la cual se consideran los registros a tener en cuenta, la cual genere un reporte mostrando lo siguiente.
//      Para aquellas asignaciones que fueron CONFIRMADAS: Materoa, promedio del tiempo que solicito para examenes por materia y fecha, ordenado de mayor
//      a menor promedio.

//      Para las que no fueron confirmadas, el intervalo de tiempo que viola la politica de no superposicion.
*/

/*DROP TABLE aula_examen;
CREATE TABLE aula_examen(nroAula int, fecha_hora date, duracion INTERVAL, codMateria VARCHAR(10), confirmado BOOLEAN);*/
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
    nro_linea BIGINT := 0;
BEGIN
 
    SELECT EXISTS (
        SELECT *
        FROM aula_examen
        WHERE confirmado = TRUE AND fecha_hora >= dia_hora
    ) INTO tiene_confirmadas;


    SELECT EXISTS (
        SELECT *
        FROM aula_examen
        WHERE confirmado = FALSE AND fecha_hora >= dia_hora
    ) INTO tiene_no_confirmadas;


    IF tiene_confirmadas OR tiene_no_confirmadas THEN
        RAISE NOTICE '----------------------------------------';
        RAISE NOTICE '    ANALISIS DE ASIGNACIONES    ';
        RAISE NOTICE '----------------------------------------';


        RAISE NOTICE '%------%------------%-----------%', 'Variable', 'Fecha', 'Horas', 'Nro Linea';


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
                nro_linea := nro_linea + 1; 
                RAISE NOTICE 'Materia: %      %         %        %', linea_record.Variable, linea_record.Fecha, linea_record.Horas, nro_linea;
            END LOOP;
        END IF;

        RAISE NOTICE '---------------------------------------------------------';
        

        IF tiene_no_confirmadas THEN
            FOR linea_record IN
                SELECT
                    nroaula::VARCHAR AS Variable,
                    fecha_hora,
                    duracion AS Horas
                FROM aula_examen
                WHERE confirmado = FALSE AND fecha_hora >= dia_hora
                ORDER BY nroaula, fecha_hora
            LOOP
                nro_linea := nro_linea + 1; 

                DECLARE
                    end_time TIMESTAMP := linea_record.fecha_hora + linea_record.Horas;
                BEGIN
 
                    RAISE NOTICE 'Aula: %   %   %    a     %        %',
                                 linea_record.Variable,
                                 TO_CHAR(DATE_TRUNC('day', linea_record.fecha_hora), 'YYYY-MM-DD'),
                                 TO_CHAR(linea_record.fecha_hora, 'HH24:MI:SS'),
                                 TO_CHAR(end_time, 'HH24:MI:SS'),
                                 nro_linea;
                END;
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


INSERT INTO aula_examen VALUES (10, '10/10/2024 10:00:00','3:00:00','78',FALSE);
/*SELECT * from aula_examen

\COPY aula_examen(nroAula, fecha_hora, duracion, codMateria) from pedido_aula.csv header delimiter ';'*/
select * from aula_examen;

SELECT * FROM analisis_asignaciones('2024-06-14 08:00:00');
w
