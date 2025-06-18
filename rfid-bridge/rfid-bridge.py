import random
import time
import asyncio
from websockets.asyncio.server import serve

debug = False

if (not debug):
    import RPi.GPIO as GPIO
    from mfrc522 import SimpleMFRC522
    reader = SimpleMFRC522()

    class RFIDReader:
        def __init__(self):
            self.reader = SimpleMFRC522()
            self.last_id = None

        def read_rfid(self):
            try:
                id, text = self.reader.read()
                if id != self.last_id:
                    self.last_id = id
                    return id, text
                else:
                    return None
            except Exception as e:
                print(f"Error reading RFID: {e}")
                return None

        def close(self):
            GPIO.cleanup()

else:
    class RFIDReader:
        def __init__(self):
            self.last_id = None

        def read_rfid(self):
            time.sleep(1)
            id = random.randint(1, 100)
            if id != self.last_id:
              self.last_id = id
              return self.last_id, "Test RFID Data"
            else:
              return None

        def close(self):
            pass

class RFIDBridge:
    def __init__(self):
        self.reader = RFIDReader()

    async def read(self, websocket):
        while True:
            print("Received read command")
            result = self.reader.read_rfid()
            if result:
                id, text = result
                print(f"RFID ID: {id}, Text: {text}")
                try:
                    await websocket.send(str(id))
                except Exception as e:
                    print(f"Error sending RFID ID: {e}")
            await asyncio.sleep(1)

    async def run(self):
      async with serve(self.read, "localhost", 10010) as server:
          print("Server started at ws://localhost:10010")
          await server.serve_forever()
              

if __name__ == "__main__":
    bridge = RFIDBridge()
    try:
        asyncio.run(bridge.run())
    except KeyboardInterrupt:
        print("Exiting...")
    finally:
        bridge.reader.close()
        if not debug:
          GPIO.cleanup()