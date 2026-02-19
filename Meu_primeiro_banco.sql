-- =============================================
-- 1. CRIAÇÃO DAS TABELAS
-- =============================================

CREATE TABLE aluno(
    id_aluno NUMBER PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    cpf VARCHAR2(11) UNIQUE NOT NULL,
    telefone VARCHAR2(20),
    data_cadastro DATE DEFAULT SYSDATE,
    status VARCHAR2(10) DEFAULT 'ATIVO'
);

CREATE TABLE treino(
    id_treino NUMBER PRIMARY KEY,
    nome_treino VARCHAR2(50) NOT NULL,
    objetivo VARCHAR2(50)
);

CREATE TABLE exercicio(
    id_exercicio NUMBER PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    grupo_muscular VARCHAR2(50)
);

CREATE TABLE treino_exercicio(
    id_treino NUMBER,
    id_exercicio NUMBER,
    series NUMBER,
    repeticoes NUMBER,
    CONSTRAINT pk_treino_exercicio PRIMARY KEY (id_treino, id_exercicio),
    CONSTRAINT fk_te_treino FOREIGN KEY (id_treino) REFERENCES treino(id_treino),
    CONSTRAINT fk_te_exercicio FOREIGN KEY (id_exercicio) REFERENCES exercicio(id_exercicio)
);

CREATE TABLE pagamento(
    id_pagamento NUMBER PRIMARY KEY,
    id_aluno NUMBER NOT NULL,
    valor NUMBER(8,2) NOT NULL,
    data_pagamento DATE DEFAULT SYSDATE,
    data_vencimento DATE NOT NULL,
    status VARCHAR2(10) DEFAULT 'PAGO',
    CONSTRAINT fk_pagamento_aluno FOREIGN KEY (id_aluno) REFERENCES aluno(id_aluno),
    CONSTRAINT ck_status_pagamento CHECK (status IN ('PAGO','PENDENTE'))
);

CREATE TABLE matricula_treino(
    id_matricula NUMBER PRIMARY KEY,
    id_aluno NUMBER NOT NULL,
    id_treino NUMBER NOT NULL,
    data_matricula DATE DEFAULT SYSDATE,
    status VARCHAR2(10) DEFAULT 'ATIVA',
    CONSTRAINT fk_mat_aluno FOREIGN KEY (id_aluno) REFERENCES aluno(id_aluno),
    CONSTRAINT fk_mat_treino FOREIGN KEY (id_treino) REFERENCES treino(id_treino),
    CONSTRAINT uq_aluno_treino UNIQUE (id_aluno, id_treino)
);

-- =============================================
-- 2. SEQUENCES
-- =============================================

CREATE SEQUENCE seq_matricula START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_pagamento START WITH 1 INCREMENT BY 1;

-- =============================================
-- 3. TRIGGER PROFISSIONAL (BLOQUEIA INADIMPLENTE)
-- =============================================

CREATE OR REPLACE TRIGGER trg_bloqueia_inadimplente
BEFORE INSERT ON matricula_treino
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM pagamento
    WHERE id_aluno = :NEW.id_aluno
    AND data_vencimento < SYSDATE;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Aluno inadimplente! Matrícula bloqueada.');
    END IF;
END;
/

-- =============================================
-- 4. PROCEDURE PROFISSIONAL
-- =============================================

CREATE OR REPLACE PROCEDURE matricular_aluno(
    p_id_aluno IN NUMBER,
    p_id_treino IN NUMBER
)
AS
    v_count NUMBER;
BEGIN
    -- Verifica inadimplência por vencimento
    SELECT COUNT(*)
    INTO v_count
    FROM pagamento
    WHERE id_aluno = p_id_aluno
    AND data_vencimento < SYSDATE;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Aluno inadimplente! Matrícula não permitida.');
    END IF;

    -- Verifica se já está matriculado
    SELECT COUNT(*)
    INTO v_count
    FROM matricula_treino
    WHERE id_aluno = p_id_aluno
    AND id_treino = p_id_treino;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Aluno já matriculado neste treino.');
    END IF;

    INSERT INTO matricula_treino(id_matricula, id_aluno, id_treino)
    VALUES (seq_matricula.NEXTVAL, p_id_aluno, p_id_treino);

END;
/

-- =============================================
-- 5. VIEW RELATÓRIO
-- =============================================

CREATE OR REPLACE VIEW vw_relatorio_aluno AS
SELECT
    a.id_aluno,
    a.nome AS nome_aluno,
    t.nome_treino,
    e.nome AS nome_exercicio,
    te.series,
    te.repeticoes,
    p.status,
    p.data_pagamento,
    p.data_vencimento
FROM aluno a
JOIN matricula_treino mt ON a.id_aluno = mt.id_aluno
JOIN treino t ON mt.id_treino = t.id_treino
JOIN treino_exercicio te ON t.id_treino = te.id_treino
JOIN exercicio e ON te.id_exercicio = e.id_exercicio
JOIN pagamento p ON p.id_pagamento = (
    SELECT MAX(id_pagamento)
    FROM pagamento
    WHERE id_aluno = a.id_aluno
);

-- =============================================
-- 6. DADOS DE TESTE
-- =============================================

-- Alunos
INSERT INTO aluno VALUES (1,'João Silva','12345678900','11999999999',SYSDATE,'ATIVO');
INSERT INTO aluno VALUES (2,'Maria Souza','98765432100','11888888888',SYSDATE,'ATIVO');

-- Treinos
INSERT INTO treino VALUES (1,'Treino A','Hipertrofia');
INSERT INTO treino VALUES (2,'Treino B','Emagrecimento');

-- Exercícios
INSERT INTO exercicio VALUES (1,'Supino','Peito');
INSERT INTO exercicio VALUES (2,'Agachamento','Perna');

-- Treino_Exercicio
INSERT INTO treino_exercicio VALUES (1,1,3,12);
INSERT INTO treino_exercicio VALUES (1,2,4,10);

-- Pagamentos
-- João em dia
INSERT INTO pagamento VALUES (seq_pagamento.NEXTVAL,1,120,SYSDATE,SYSDATE+30,'PAGO');

-- Maria vencido
INSERT INTO pagamento VALUES (seq_pagamento.NEXTVAL,2,120,SYSDATE,SYSDATE-5,'PENDENTE');

COMMIT;

-- =============================================
-- 7. TESTES
-- =============================================

BEGIN
    matricular_aluno(1,1); -- Deve funcionar
END;
/

BEGIN
    matricular_aluno(2,1); -- Deve bloquear
END;
/

-- =============================================
-- FIM DO SCRIPT
-- =============================================
