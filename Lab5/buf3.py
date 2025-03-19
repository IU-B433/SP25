import subprocess

# The command to run your program
command = './buf3'

# Your input data
input_data = 'A' * 4 
input_data += '123456789'

# Run the command with the input
process = subprocess.Popen(command, stdin=subprocess.PIPE)
process.communicate(input_data.encode())