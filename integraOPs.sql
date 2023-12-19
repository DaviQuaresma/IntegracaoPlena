
--DECLARE @_CODIGO_FILIAL VARCHAR(4) = 220 --OPÇÕES [0102|0103|0104|0105|210|220|280|510]
--DECLARE @_DATA AS DATE = '20230210'
--DECLARE @_DATA_FINAL AS DATE = '20230331'
--DECLARE @_TIPO_INTEGRACAO AS VARCHAR(50) = 'INTEGRAR' --OPÇÕES [ESTORNAR|INTEGRAR]
--DECLARE @_TIPO_E_S AS VARCHAR(50) = 'TODOS' --OPÇÕES [TODOS|ENTRADA|SAIDA]
--DECLARE @_PRODUTO AS VARCHAR(50) = 'TODOS' --OPÇÕES [TODOS|SKU]   TODOS OU SKU POR SKU
--DECLARE @_CHAVE_DE_FATO AS VARCHAR(50) = 'TODOS' --OPÇÕES [TODOS|CHAVE_FATO]
--DECLARE @_NUM_DO_ITEM AS VARCHAR(50) = 'TODOS' --OPÇÕES [TODOS|NUM_DO_ITEM] 
--DECLARE @_COMANDO AS VARCHAR(50) = 'PREVIEW' --OPÇÕES [PREVIEW|EXECUTE]
--DECLARE @_LISTA_SOMENTE_ERRO AS VARCHAR(50) = 'SIM' --OPÇÕES [SIM|NAO]
--DECLARE @STATUS_ERRO AS VARCHAR(50) = '3' --OPÇÕES []

/* EXECUTA DE/PARA COM FILIAL ATAK */
DECLARE @FILIAL AS VARCHAR(4)
IF		@_CODIGO_FILIAL = 0102	OR @_CODIGO_FILIAL= 210 BEGIN SET @FILIAL = 210 END
ELSE IF @_CODIGO_FILIAL = 0103 OR @_CODIGO_FILIAL = 220 BEGIN SET @FILIAL = 220 END
ELSE IF @_CODIGO_FILIAL = 0104 OR @_CODIGO_FILIAL = 280 BEGIN SET @FILIAL = 280 END
ELSE IF @_CODIGO_FILIAL = 0105 OR @_CODIGO_FILIAL = 510 BEGIN SET @FILIAL = 510 END;

DECLARE @CHAVE_DE_FATO AS VARCHAR(50);
DECLARE @NUM_DO_ITEM AS VARCHAR(50);
DECLARE @tbRetorno TABLE (Seq int null ,Retorno varchar(max) null,Comando VARCHAR(20) NULL,Tipo VARCHAR(20) NULL,Filial VARCHAR(20) NULL,Data_inicial datetime null,Data_final datetime null,Tipo_E_S VARCHAR(20) NULL,
						Produto VARCHAR(20) NULL,Chave_fato VARCHAR(20) NULL,Num_item int NULL,Qtde_Pri float NULL);

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IF @_LISTA_SOMENTE_ERRO = 'SIM'
	BEGIN
		DECLARE Lista_erros CURSOR FOR 
		SELECT DISTINCT Chave_fato,Num_item FROM (
				SELECT
				ENT_I.Chave_fato,ENT_I.Num_item,
				CASE
					WHEN B1_COD IS NULL THEN '1'--'Produto sem De/Para com Protheus'
					WHEN B1_COD <> D3_COD THEN '2'--'Gerou movimentação com produto Errado'
					WHEN ENT_I.Qtde_pri <> D3.Qtde_pri THEN '3'--'Qtde Divergente'
					WHEN D3.Qtde_pri  is null THEN '4'--'Não Integrado'
					WHEN ENT_I.Qtde_pri <> ISNULL(D3.Qtde_pri,0) THEN '3'--'Qtde Divergente'
					WHEN ENT_I.Qtde_aux <> ISNULL(D3.Qtde_aux,0) THEN '5'--'Segunda Qtde Divergente'
					WHEN ENT.Data_Estoque <> D3.Data_Estoque THEN '6'--'Dt Estoque Atak <> Dt Emissão PROTHEUS'
					WHEN COUNT(*) OVER (PARTITION BY ENT.Chave_fato,ENT_I.Cod_produto,ENT_I.Num_item) > 1THEN '7'--'Evento com duplicidade'
					ELSE '8'--'Ok'
				END AS ID_Critica,
				CASE
					WHEN B1_COD IS NULL THEN 'Produto sem De/Para com Protheus'
					WHEN B1_COD <> D3_COD THEN 'Gerou movimentação com produto Errado'
					WHEN ENT_I.Qtde_pri <> D3.Qtde_pri THEN 'Qtde Divergente'
					WHEN D3.Qtde_pri  is null THEN 'Não Integrado'
					WHEN ENT_I.Qtde_pri <> ISNULL(D3.Qtde_pri,0) THEN 'Qtde Divergente'
					WHEN ENT_I.Qtde_aux <> ISNULL(D3.Qtde_aux,0) THEN 'Segunda Qtde Divergente'
					WHEN ENT.Data_Estoque <> D3.Data_Estoque THEN 'Dt Estoque Atak <> Dt Emissão PROTHEUS'
					WHEN COUNT(*) OVER (PARTITION BY ENT.Chave_fato,ENT_I.Cod_produto,ENT_I.Num_item) > 1THEN 'Evento com duplicidade'
					ELSE 'Ok'
				END AS Critica
				FROM tbSaidas ENT WITH(NOLOCK) 
				INNER JOIN tbSaidasitem ENT_I WITH(NOLOCK)  ON  ENT_I.Chave_fato =  ENT.Chave_fato
				INNER JOIN tbTipomvestoque TMV WITH(NOLOCK)  ON ENT.Cod_tipo_mv = TMV.Cod_tipo_mv AND TMV.Perfil_tmv IN ('ABT0104', 'ABT0105', 'ABT0106', 'PCP0301', 'PCP0302')
				LEFT JOIN tbProduto P ON P.Cod_produto =ENT_I.Cod_produto
				LEFT JOIN SN_SB1010 B1 WITH(NOLOCK) ON B1.D_E_L_E_T_ = '' AND B1_ZCODLEG = ENT_I.Cod_produto COLLATE SQL_Latin1_General_CP1_CI_AS
				LEFT JOIN (
							SELECT 
							D3_FILIAL,D3_COD,D3_TM,D3_OP,
							CASE
								WHEN D3_TM = '010' THEN 'Apontamento'
								WHEN D3_TM = '501' THEN 'Requisição'
								ELSE D3_TM
							END AS Tipo,
							D3_ZOPATK AS Chave_fato_MP,  
							D3_ZCTRATK AS Chave_fato, 
							D3_EMISSAO AS Data_Estoque,
							SUM((CAST(D3_QUANT AS NUMERIC(15,3)))) AS Qtde_pri,
							SUM((CAST(D3_QTSEGUM AS NUMERIC(15,3)))) AS Qtde_aux,
							CAST(D3_ZITEATK AS int) AS Num_item
							FROM SN_SD3010 D3 WITH(NOLOCK) 
							WHERE D3_TM NOT IN ('999','498') AND ISNULL(D3_ZOPATK,'') NOT LIKE '%-%'AND D3_ESTORNO = ''AND D3.D_E_L_E_T_ = ''
							GROUP BY D3_FILIAL,D3_COD,D3_TM,D3_OP,D3_ZOPATK,D3_ZCTRATK,D3_EMISSAO,D3_ZITEATK
						) AS D3 ON D3.Chave_fato = ENT.Chave_fato COLLATE SQL_Latin1_General_CP1_CI_AS AND D3.Num_item = ENT_I.Num_item-- AND B1_COD = D3.D3_COD 

				WHERE 
				@_LISTA_SOMENTE_ERRO = 'SIM' AND
				(@_PRODUTO = 'TODOS' OR ENT_I.Cod_produto = @_PRODUTO) AND
				(@_TIPO_E_S = 'TODOS' OR @_TIPO_E_S = 'ENTRADA') AND
				(@_NUM_DO_ITEM = 'TODOS' OR CAST(ENT_I.Num_item AS varchar(10)) = @_NUM_DO_ITEM) AND
				(@_CHAVE_DE_FATO = 'TODOS' OR ENT_I.Chave_fato = @_CHAVE_DE_FATO) AND
				ENT.Data_Estoque BETWEEN @_DATA AND @_DATA_FINAL AND
				ENT.Cod_filial IN (@FILIAL) AND
				ENT_I.Num_subItem = '0' AND
				(ENT_I.Qtde_pri <> 0 OR ENT_I.Qtde_pri<> 0)

				UNION ALL

				SELECT
				ENT_I.Chave_fato,ENT_I.Num_item,
				CASE
					WHEN B1_COD IS NULL THEN '1'--'Produto sem De/Para com Protheus'
					WHEN B1_COD <> D3_COD THEN '2'--'Gerou movimentação com produto Errado'
					WHEN ENT_I.Qtde_pri <> D3.Qtde_pri THEN '3'--'Qtde Divergente'
					WHEN D3.Qtde_pri  is null THEN '4'--'Não Integrado'
					WHEN ENT_I.Qtde_pri <> ISNULL(D3.Qtde_pri,0) THEN '3'--'Qtde Divergente'
					WHEN ENT_I.Qtde_aux <> ISNULL(D3.Qtde_aux,0) THEN '5'--'Segunda Qtde Divergente'
					WHEN ENT.Data_Estoque <> D3.Data_Estoque THEN '6'--'Dt Estoque Atak <> Dt Emissão PROTHEUS'
					WHEN COUNT(*) OVER (PARTITION BY ENT.Chave_fato,ENT_I.Cod_produto,ENT_I.Num_item) > 1THEN '7'--'Evento com duplicidade'
					ELSE '8'--'Ok'
				END AS ID_Critica,
				CASE
					WHEN B1_COD IS NULL THEN 'Produto sem De/Para com Protheus'
					WHEN B1_COD <> D3_COD THEN 'Gerou movimentação com produto Errado'
					WHEN ENT_I.Qtde_pri <> D3.Qtde_pri THEN 'Qtde Divergente'
					WHEN D3.Qtde_pri  is null THEN 'Não Integrado'
					WHEN ENT_I.Qtde_pri <> ISNULL(D3.Qtde_pri,0) THEN 'Qtde Divergente'
					WHEN ENT_I.Qtde_aux <> ISNULL(D3.Qtde_aux,0) THEN 'Segunda Qtde Divergente'
					WHEN ENT.Data_Estoque <> D3.Data_Estoque THEN 'Dt Estoque Atak <> Dt Emissão PROTHEUS'
					WHEN COUNT(*) OVER (PARTITION BY ENT.Chave_fato,ENT_I.Cod_produto,ENT_I.Num_item) > 1THEN 'Evento com duplicidade'
					ELSE 'Ok'
				END AS Critica
				FROM tbEntradas ENT WITH(NOLOCK) 
				INNER JOIN tbEntradasitem ENT_I WITH(NOLOCK)  ON  ENT_I.Chave_fato =  ENT.Chave_fato
				INNER JOIN tbTipomvestoque TMV WITH(NOLOCK)  ON ENT.Cod_tipo_mv = TMV.Cod_tipo_mv AND TMV.Perfil_tmv IN ('ABT0104', 'ABT0105', 'ABT0106', 'PCP0301', 'PCP0302')
				LEFT JOIN tbProduto P ON P.Cod_produto =ENT_I.Cod_produto
				LEFT JOIN SN_SB1010 B1 WITH(NOLOCK) ON B1.D_E_L_E_T_ = '' AND B1_ZCODLEG = ENT_I.Cod_produto COLLATE SQL_Latin1_General_CP1_CI_AS
				LEFT JOIN (
							SELECT 
							D3_FILIAL,D3_COD,D3_TM,D3_OP,
							CASE
								WHEN D3_TM = '010' THEN 'Apontamento'
								WHEN D3_TM = '501' THEN 'Requisição'
								ELSE D3_TM
							END AS Tipo,
							D3_ZOPATK AS Chave_fato_MP,  
							D3_ZCTRATK AS Chave_fato, 
							D3_EMISSAO AS Data_Estoque,
							SUM((CAST(D3_QUANT AS NUMERIC(15,3)))) AS Qtde_pri,
							SUM((CAST(D3_QTSEGUM AS NUMERIC(15,3)))) AS Qtde_aux,
							CAST(D3_ZITEATK AS int) AS Num_item
							FROM SN_SD3010 D3 WITH(NOLOCK) 
							WHERE D3_TM NOT IN ('999','498') AND ISNULL(D3_ZOPATK,'') NOT LIKE '%-%'AND D3_ESTORNO = ''AND D3.D_E_L_E_T_ = ''
							GROUP BY D3_FILIAL,D3_COD,D3_TM,D3_OP,D3_ZOPATK,D3_ZCTRATK,D3_EMISSAO,D3_ZITEATK
						) AS D3 ON D3.Chave_fato = ENT.Chave_fato COLLATE SQL_Latin1_General_CP1_CI_AS AND D3.Num_item = ENT_I.Num_item
				WHERE 
				@_LISTA_SOMENTE_ERRO = 'SIM' AND
				(@_PRODUTO = 'TODOS' OR ENT_I.Cod_produto = @_PRODUTO) AND
				(@_TIPO_E_S = 'TODOS' OR @_TIPO_E_S = 'ENTRADA') AND
				(@_NUM_DO_ITEM = 'TODOS' OR CAST(ENT_I.Num_item AS varchar(10)) = @_NUM_DO_ITEM) AND
				(@_CHAVE_DE_FATO = 'TODOS' OR ENT_I.Chave_fato = @_CHAVE_DE_FATO) AND
				ENT.Data_Estoque BETWEEN @_DATA AND @_DATA_FINAL AND
				ENT.Cod_filial IN (@FILIAL) AND
				ENT_I.Num_subItem = '0' AND
				(ENT_I.Qtde_pri <> 0 OR ENT_I.Qtde_pri<> 0)
		) TB1
		WHERE 
		TB1.ID_Critica NOT IN ('8')
		OPEN Lista_erros;  
  
		FETCH NEXT  FROM Lista_erros INTO @CHAVE_DE_FATO,@NUM_DO_ITEM;
		WHILE @@FETCH_STATUS = 0  
		BEGIN
			INSERT INTO @tbRetorno
			EXECUTE spIntegracaoProtheusMaintenance
			 @_CODIGO_FILIAL
			,@_DATA
			,@_DATA_FINAL
			,@_TIPO_INTEGRACAO
			,@_TIPO_E_S
			,@_PRODUTO
			,@CHAVE_DE_FATO
			,@NUM_DO_ITEM
			,@_COMANDO
		   FETCH NEXT FROM Lista_erros  INTO @CHAVE_DE_FATO,@NUM_DO_ITEM;
		END  
  
		CLOSE Lista_erros;  
		DEALLOCATE Lista_erros;  
	END 
ELSE
	BEGIN
		INSERT INTO @tbRetorno
		EXECUTE spIntegracaoProtheusMaintenance
		 @_CODIGO_FILIAL
		,@_DATA
		,@_DATA_FINAL
		,@_TIPO_INTEGRACAO
		,@_TIPO_E_S
		,@_PRODUTO
		,@_CHAVE_DE_FATO
		,@_NUM_DO_ITEM
		,@_COMANDO
	END;

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM @tbRetorno
ORDER BY CAST( Seq AS INT)