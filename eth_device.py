import tkinter as tk
import socket
import threading
import sys
import struct
INTERFACE = "enp2s0f1"


MY_IP = [192, 168, 0, 110]
FPGA_IP = [192, 168, 0, 111]

MY_MAC = b"\xf0\x76\x1c\x3e\xd0\x21"
FPGA_MAC = b"\xe8\x6a\x64\xe7\xe8\x30" 
SEND_STRING = b"LEDs CHANGED!     "

class EthExampleApp:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA Control (Linux Raw Socket)")
        self.running = True
        self.sw_value_str = "0000"

        self.create_window()
        self.create_socket()

        self.receiver_thread = threading.Thread(target=self.receive_loop)
        self.receiver_thread.daemon = True
        self.receiver_thread.start()

        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

    def create_socket(self):
        try:
            self.s_inst = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
            self.s_inst.bind((INTERFACE, 0))
        except PermissionError:
            print("ОШИБКА: Запустите через SUDO")
            sys.exit()

    def create_window(self):
        tk.Label(self.root, text="Введите значение LED:").pack(pady=5)
        self.entry_text = tk.StringVar(value="0")
        self.entry = tk.Entry(self.root, textvariable=self.entry_text)
        self.entry.pack(pady=5)

        tk.Button(self.root, text="Установить LED", command=self.set_led_value, bg="lightblue").pack(pady=5, fill='x')
        tk.Button(self.root, text="Скопировать Switches в LEDs", command=self.switches_to_leds).pack(pady=5, fill='x')

        self.led_label = tk.Label(self.root, text="Leds: 0x0000", font=("Courier", 12))
        self.led_label.pack(pady=10)

        self.switches_label = tk.Label(self.root, text="Ожидание данных...", font=("Courier", 14, "bold"), fg="blue")
        self.switches_label.pack(pady=20)
    def calculate_ip_checksum(self, data):
        """ Стандартный расчет контрольной суммы IP заголовка """
        if len(data) % 2: data += b'\x00'
        res = sum(struct.unpack("!%dH" % (len(data) // 2), data))
        while (res >> 16):
            res = (res & 0xFFFF) + (res >> 16)
        return (~res) & 0xFFFF
    def send_packet(self, led_value):
        try:
            payload = SEND_STRING + struct.pack("!B", led_value & 0xFF)
            
            udp_len = 8 + len(payload)
            udp_header = struct.pack("!HHHH", 17767, 17767, udp_len, 0)
            
            ip_tot_len = 20 + udp_len
            ip_header_base = struct.pack("!BBHHHBBH4s4s", 
                0x45, 0, ip_tot_len, 54321, 0, 64, 17, 0, 
                bytes(MY_IP), bytes(FPGA_IP))
            ip_check = self.calculate_ip_checksum(ip_header_base)
            ip_header = struct.pack("!BBHHHBBH4s4s", 
                0x45, 0, ip_tot_len, 54321, 0, 64, 17, ip_check, 
                bytes(MY_IP), bytes(FPGA_IP))

            eth_header = FPGA_MAC + MY_MAC + b"\x08\x00"

            full_packet = eth_header + ip_header + udp_header + payload
            self.s_inst.send(full_packet)
            print(f"Sending packet: {full_packet.hex()}")
        except Exception as e:
            print(f"Ошибка при отправке пакета: {e}")

    def receive_loop(self):
        while self.running:
            try:
                raw_data = self.s_inst.recv(2048)
                if FPGA_MAC in raw_data[6:12]:
                    payload = raw_data[42:].decode("utf-8", errors="ignore")
                    print(f"Received: {payload.strip()}")
                    
                    if "0x" in payload:
                        hex_val = payload.split("0x")[1][0] 
                        self.sw_value_str = hex_val
                        self.switches_label.config(text=f"Switches: 0x{hex_val}")
            except:
                pass
    def set_led_value(self):
        try:
            val = int(self.entry_text.get())
            self.led_label.config(text=f"Leds: 0x{val:04x}")
            self.send_packet(val)
        except:
            pass

    def switches_to_leds(self):
        try:
            val = int(self.sw_value_str, 16)
            self.entry_text.set(str(val))
            self.set_led_value()
        except:
            pass

    def on_closing(self):
        self.running = False
        self.s_inst.close()
        self.root.destroy()

if __name__ == "__main__":
    root = tk.Tk()
    app = EthExampleApp(root)
    root.mainloop()
