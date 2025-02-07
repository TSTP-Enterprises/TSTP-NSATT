import subprocess
from flask import Response, request, render_template, stream_with_context, jsonify
from datetime import datetime

def register_console_routes(app):
    @app.route('/console', methods=['GET', 'POST'])
    def console():
        if request.method == 'POST':
            command = request.form.get('command')
            if not command:
                return jsonify({"error": "No command provided"}), 400
            
            try:
                result = subprocess.getoutput(command)
                return jsonify({"output": result})
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        return render_template('console.html')

    @app.route('/console/stream')
    def console_stream():
        command = request.args.get('command')
        if not command:
            return jsonify({"error": "No command provided"}), 400

        def generate():
            process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            for line in iter(process.stdout.readline, ''):
                yield f"data: {line.strip()}\n\n"
            process.stdout.close()
            process.wait()

        return Response(stream_with_context(generate()), content_type='text/event-stream')

    @app.route('/console/save', methods=['POST'])
    def save_console_output():
        try:
            output = request.json.get('output', '')
            if not output:
                return jsonify({"error": "No output to save"}), 400

            filename = f"console_output_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
            with open(filename, 'w') as f:
                f.write(output)
            return jsonify({"message": f"Output saved to {filename}"}), 200
        except Exception as e:
            return jsonify({"error": str(e)}), 500
