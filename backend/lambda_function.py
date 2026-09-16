import json
import logging
import boto3
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Inicializar cliente de DynamoDB
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'GritosTotales')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    # Detectar si es un GET (carga inicial) o un POST (alguien presionó el botón)
    method = event.get('requestContext', {}).get('http', {}).get('method', 'POST')
    
    # Headers necesarios para evitar errores CORS en el navegador
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET',
        'Content-Type': 'application/json'
    }

    try:
        if method == 'GET':
            # Devolver el contador actual para todos los visitantes
            response = table.get_item(Key={'id': 'counter'})
            count = int(response.get('Item', {}).get('total', 0))
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'total': count})
            }
        
        else:
            # POST: Incrementar el contador atómicamente (UpdateExpression)
            logger.info("¡Grito de Independencia recibido!")
            response = table.update_item(
                Key={'id': 'counter'},
                # Use a placeholder like #t instead of total
                UpdateExpression="ADD #t :inc",
                # Map the placeholder to the actual attribute name
                ExpressionAttributeNames={'#t': 'total'},
                ExpressionAttributeValues={':inc': 1},
                ReturnValues="UPDATED_NEW" # Devuelve el nuevo total inmediatamente
            )
            count = int(response['Attributes']['total'])
            
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'message': '¡Viva México!', 'total': count})
            }
            
    except Exception as e:
        logger.error(f"Error con DynamoDB: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Error interno de base de datos'})
        }