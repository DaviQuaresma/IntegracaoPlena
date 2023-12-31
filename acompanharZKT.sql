--ACOMPANHAMENTO DA ZKT PARA VER OS ITENS QUE ESTÃO AGUARDANDO OU JÁ FORAM INTEGRADOS

SELECT ZKT_STATUS,CONVERT(VARCHAR(MAX),ZKT_RETURN),
ZKT_JSON = CONVERT(VARCHAR(MAX),ZKT_JSON),* 
FROM ZKT010 Z
WHERE ZKT_DTIMP = REPLACE(CAST(GETDATE() AS DATE),'-','')

AND ZKT_HRIMP >= '11:50'
AND ZKT_JSON LIKE '%202310%'
AND ZKT_ORIGEM = 'ATAK'
AND ZKT_STATUS <> ''
and ZKT_ID = 'RAA01'
AND ZKT_FILORI = '0102'

--ACOMPANHAMENTO DA FILA DE EVENTOS PARA VER SE A FILA ESTÁ GRANDE, AI A INTEGRAÇÕES FICA MAIS LENTA

SELECT ZKT_STATUS,CONVERT(VARCHAR(MAX),ZKT_RETURN),
ZKT_JSON = CONVERT(VARCHAR(MAX),ZKT_JSON),* 
FROM ZKT010 Z
WHERE ZKT_ORIGEM = 'ATAK'
AND ZKT_STATUS = '1'


--Comando para matar todos envios de eventos, mudando estados para pendente liberando a fila
SELECT 
ZKT_STATUS,CONVERT(VARCHAR(MAX),ZKT_RETURN),
* 
--BEGIN TRAN  UPDATE Z SET ZKT_STATUS = 'X'
--COMMIT 

FROM ZKT010 Z

WHERE ZKT_DTIMP = REPLACE(CAST(GETDATE() AS DATE),'-','')
AND ZKT_HRIMP >= '10:19'
AND ZKT_JSON  NOT LIKE '%20231027%'
AND ZKT_ORIGEM = 'ATAK'
and ZKT_STATUS = '1'