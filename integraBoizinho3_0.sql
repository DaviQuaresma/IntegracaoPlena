-----------------------------------------------------REENVIA OP BOIZINHO--------------------------------------------------------


DECLARE @TEXTO VARCHAR(1024),
		@PERFIL_TMV CHAR(7),
		@USUARIO CHAR(20),
		@TIPO_EVENTO VARCHAR(2),
		@TIPO_OPERACAO VARCHAR(2),
		@REENVIA_EVENTOS VARCHAR(1),
		@TIPO_VIEW_INTEGRA VARCHAR(15),
		@CHF VARCHAR(9),
		@STATUS VARCHAR(30),
		@DATA_INICIAL  DATE,
		@DATA_FINAL  DATE,
		@FILIAL VARCHAR(5),
		@_CODIGO_FILIAL VARCHAR(5)

------------------------------------------------------------------------------------
SET @_CODIGO_FILIAL = '0103'--OPÇÕES [0102|0103|0104|0105|210|220|280|510]
SET @DATA_INICIAL = '20231003'
SET @DATA_FINAL = '20231003'
SET @TIPO_OPERACAO = '15'--- INTEGRAR = 15  ||| ESTORNAR = 16
SET @TIPO_VIEW_INTEGRA = 'VISUALIZAR'--- VISUALIZAR OU EXECUTAR
------------------------------------------------------------------------------------

SET @STATUS = 'DIVERGENTE' -- NÃO MEXE
SET @REENVIA_EVENTOS = 'S' -- NÃO MEXE

/* EXECUTA DE/PARA COM FILIAL ATAK */
IF		@_CODIGO_FILIAL = 0102	OR @_CODIGO_FILIAL= 210 BEGIN SET @FILIAL = 210 END
ELSE IF @_CODIGO_FILIAL = 0103 OR @_CODIGO_FILIAL = 220 BEGIN SET @FILIAL = 220 END
ELSE IF @_CODIGO_FILIAL = 0104 OR @_CODIGO_FILIAL = 280 BEGIN SET @FILIAL = 280 END
ELSE IF @_CODIGO_FILIAL = 0105 OR @_CODIGO_FILIAL = 510 BEGIN SET @FILIAL = 510 END;


SELECT 
Chave_fato,
'DBATAK' AS Cod_funcionario,
MV.Perfil_tmv,
CASE 
	WHEN MV.Perfil_tmv IN ('ABT0103','ABT0112','ABT0113') THEN '1' 
	WHEN MV.Perfil_tmv IN ('CPA0101') THEN '2' 
	WHEN MV.Perfil_tmv IN ('VDA0203') THEN '10'
	WHEN MV.Perfil_tmv IN ('VDA0501') THEN '9'
END AS TIPO_EVENTO,
CASE 
	WHEN MV.Perfil_tmv IN ('ABT0103') THEN 'Romaneio de Gado'
	WHEN MV.Perfil_tmv IN ('ABT0112') THEN 'Bovino/Suíno - Abate - Romaneio de abate valorizado peso vivo' 
	WHEN MV.Perfil_tmv IN ('ABT0113') THEN 'Bovino/Suíno - Abate - Romaneio de abate valorizado peso morto' 
	WHEN MV.Perfil_tmv IN ('CPA0101') THEN 'Pedido de Compra' 
	WHEN MV.Perfil_tmv IN ('VDA0203') THEN 'Autorização Devolução Venda'
	WHEN MV.Perfil_tmv IN ('VDA0501') THEN 'Romaneio de Venda'
END AS TEXTO
INTO #temp_integracao
FROM TBENTRADAS E
INNER JOIN tbTipoMvEstoque MV ON E.Cod_tipo_mv = MV.Cod_tipo_mv AND MV.Integra_AveSoft = 'S' AND MV.Perfil_tmv IN ('ABT0103','ABT0112','ABT0113','CPA0101','VDA0203','VDA0501')
WHERE 
E.Cod_tipo_mv = 'T817'
AND Chave_fato IN (
SELECT 
DISTINCT Chave_fato
FROM(
		SELECT 
		TOP 1000000
		CASE 
			WHEN TB1.D3_FILIAL = 0102 THEN '0102 - CONTAGEM'
			WHEN TB1.D3_FILIAL = 0103 THEN '0103 - PARA DE MINAS'
			WHEN TB1.D3_FILIAL = 0104 THEN '0104 - PORANGATU'
			WHEN TB1.D3_FILIAL = 0105 THEN '0105 - PARAISO'
			ELSE TB1.D3_FILIAL
		END AS D3_FILIAL,

		CAST(TB1.D3_DTPRD AS date) AS D3_DTPRD,
		CAST(D3_EMISSAO AS date) AS D3_EMISSAO,
		CASE 
			WHEN TB1.D3_CF = 'PR0' THEN 'APONTAMENTO'
			WHEN TB1.D3_CF = 'RE0' THEN 'REQUISIÇÃO'
			ELSE TB1.D3_CF
		END AS D3_CF,
		TB1.B1_ZCODLEG,ISNULL(B1_COD,'') AS B1_COD,TB1.B1_DESC,
		CASE 
			WHEN TB1.D3_CF = 'PR0' AND ISNULL(D3_UM,'') = '' THEN 'KG'
			WHEN TB1.D3_CF = 'RE0' AND ISNULL(D3_UM,'') = '' THEN 'CB'
			ELSE D3_UM
		END AS D3_UM,
		TB1.D3_QUANT AS D3_QUANT_ATAK,
		ISNULL(D3.D3_QUANT,0) AS D3_QUANT,
		CASE 
			WHEN  D3.D3_ZOPATK IS NULL THEN 'PENDENTE INTEGRACAO'
			WHEN CAST(ISNULL(D3.D3_QUANT,'0') AS money) <> CAST(TB1.D3_QUANT AS money)THEN 'QUANT. COM DIVERGECIA'
			WHEN COUNT(*) OVER(PARTITION BY D3_OP) <> 2 THEN 'OP M.P <> OP P.A'
 			WHEN CAST(ISNULL(D3.D3_QUANT,'0') AS money) = CAST(TB1.D3_QUANT AS money) AND TB1.D3_QUANT <> 0 THEN 'OK'
		END AS VERIFICADOR,
		CONTRATO_ATAK,TB1.D3_ZOPATK,D3_OP,Chave_fato
		FROM (
				SELECT 
				CASE 
					WHEN E.Cod_filial = 210 THEN '0102'
					WHEN E.Cod_filial = 220 THEN '0103'
					WHEN E.Cod_filial = 280 THEN '0104'
					WHEN E.Cod_filial = 510 THEN '0105'
					ELSE E.Cod_filial
				END AS D3_FILIAL,
				CONCAT(EI.Chave_fato,'-',EI.Num_item) AS D3_ZOPATK,
				EI.Chave_fato AS Chave_fato,
				replace(cast(E.Data_movto as date),'-','') AS D3_DTPRD,CASE WHEN EI.Num_subItem = 0 THEN 'RE0' ELSE 'PR0'  END AS D3_CF,
				SUM(EI.Qtde_pri) AS D3_QUANT,
				CASE
					WHEN PR.Sexo = 'M' AND EI.Num_subItem = 0 THEN '80'
					WHEN PR.Sexo = 'F' AND EI.Num_subItem = 0 THEN '90'
					ELSE EI.Cod_produto 
				END AS B1_ZCODLEG,
				CASE
					WHEN PR.Sexo = 'M' AND EI.Num_subItem = 0 THEN 'BOVINO MACHO - ABATE'
					WHEN PR.Sexo = 'F' AND EI.Num_subItem = 0 THEN 'BOVINO FEMEA - ABATE'
					ELSE P.Desc_produto_est		
				END AS B1_DESC,
				E.Num_docto AS CONTRATO_ATAK
				FROM tbEntradas E WITH(NOLOCK)
				INNER JOIN tbEntradasItem EI WITH(NOLOCK) ON EI.Chave_fato = E.Chave_fato
				LEFT JOIN tbProdutoRef PR WITH(NOLOCK) ON PR.Cod_produto = EI.Cod_produto
				LEFT JOIN tbProduto P WITH(NOLOCK) ON P.Cod_produto = EI.Cod_produto
				where Cod_tipo_mv = 'T817'
				AND Data_movto between @DATA_INICIAL and @DATA_FINAL
				AND E.Cod_filial IN (@FILIAL)
				GROUP BY E.Cod_filial,E.Data_movto,EI.Chave_fato,EI.Num_item,EI.Num_subItem,E.Num_docto,EI.Cod_produto,PR.Sexo,P.Desc_produto_est
		) TB1
		LEFT JOIN SN_SB1010 B1 ON B1.B1_ZCODLEG = TB1.B1_ZCODLEG  COLLATE SQL_Latin1_General_CP1_CI_AS AND B1.D_E_L_E_T_ = ''
		LEFT JOIN ( SELECT D3_FILIAL,D3_ZOPATK,D3_EMISSAO,D3_COD,D3_UM,D3_CF,SUM(D3_QUANT) AS D3_QUANT,D3_OP
					FROM SN_SD3010 WITH(NOLOCK)
					WHERE D_E_L_E_T_ = ''
					AND D3_ZOPATK LIKE '%-%' AND D3_ESTORNO <> 'S'
					GROUP BY D3_FILIAL,D3_ZOPATK,D3_EMISSAO,D3_UM,D3_COD,D3_CF,D3_OP) D3 ON TB1.D3_ZOPATK = D3.D3_ZOPATK  COLLATE SQL_Latin1_General_CP1_CI_AS 
																				AND TB1.D3_FILIAL = D3.D3_FILIAL   COLLATE SQL_Latin1_General_CP1_CI_AS
																				AND LEFT(TB1.D3_CF,2) = LEFT(D3.D3_CF,2)  COLLATE SQL_Latin1_General_CP1_CI_AS
																				--AND B1_COD = D3_COD

	ORDER BY TB1.D3_FILIAL,TB1.D3_DTPRD,TB1.D3_ZOPATK,TB1.D3_CF DESC,VERIFICADOR,TB1.B1_ZCODLEG,TB1.B1_DESC     
	) TB1
WHERE
(VERIFICADOR IN ('PENDENTE INTEGRACAO','QUANT. COM DIVERGECIA','OP M.P <> OP P.A')  AND @STATUS = 'DIVERGENTE') OR( @STATUS <> 'DIVERGENTE')


)




IF @TIPO_VIEW_INTEGRA = 'EXECUTAR'
	BEGIN

		DECLARE reenvia_evento CURSOR FOR 
		SELECT *FROM #temp_integracao

		OPEN reenvia_evento;  
  
		FETCH NEXT  FROM reenvia_evento INTO @CHF, @USUARIO,@PERFIL_TMV,@TIPO_EVENTO,@TEXTO;
		WHILE @@FETCH_STATUS = 0  
		BEGIN   

		   
				IF @REENVIA_EVENTOS <> 'S'
				BEGIN
					PRINT CONCAT('TESTANDO REGISTRO: ',@CHF,'-',@USUARIO,'-',@PERFIL_TMV,'-',@TIPO_EVENTO,'-',@TEXTO)
				END

				IF @REENVIA_EVENTOS = 'S'
				BEGIN
					--EXEC [SP_RegistraEventoIntegracao] 'INC-EITM' , NULL, @TEXTO 
					DECLARE @DT DATETIME
					SET @DT = GETDATE()
					EXEC [SP_RegistraEventoIntegracao] 1, @TIPO_EVENTO, @CHF, @USUARIO, @DT, null, null, @TEXTO, null, @PERFIL_TMV, @TIPO_OPERACAO, null, null, null, null
					PRINT CONCAT('REENVIANDO REGISTRO: ',@CHF,'-',@USUARIO,'-',@PERFIL_TMV,'-',@TIPO_EVENTO,'-',@TEXTO)
				END;

		   FETCH NEXT FROM reenvia_evento  INTO @CHF, @USUARIO,@PERFIL_TMV,@TIPO_EVENTO,@TEXTO;
		END    
		CLOSE reenvia_evento;  
		DEALLOCATE reenvia_evento;  
	END
ELSE
	BEGIN
		SELECT *FROM #temp_integracao
	END;

drop table #temp_integracao


--Lucas Gomes Marinho
http://spl-dwprd-01/relatorios/report/INTEGRA%C3%87%C3%95ES/PROTHEUS%20X%20ATAK/ESTOQUE/INTEGRA%C3%87%C3%83O%20-%20DISCREP%C3%82NCIAS%20DE%20MOVIMENTA%C3%87%C3%83O%20DE%20PRODU%C3%87%C3%83O
Sempre rodar esse relatório, se tiver algo enviar para Tarcicio ou Dutra para matar a D3, atenção, durante o processamento 
( Especialmente de "boizinhos", pode ser que apareça algo)