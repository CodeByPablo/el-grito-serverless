import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info("¡Se ha recibido un Grito de Independencia!")
    logger.info(f"Evento crudo: {json.dumps(event)}")
    
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'OPTIONS,POST',
            'Content-Type': 'application/json' 
        },
        'body': json.dumps({'message': '¡Viva México! Evento registrado.'})
    }