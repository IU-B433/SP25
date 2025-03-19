import subprocess

# The command to run your program
command = './buf1'

# Your input data
input_data = '123456789'

# Run the command with the input
process = subprocess.Popen(command, stdin=subprocess.PIPE)
process.communicate(input_data.encode())