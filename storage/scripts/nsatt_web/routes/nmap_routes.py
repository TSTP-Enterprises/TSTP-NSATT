from flask import render_template, request, session, redirect, url_for, Response, stream_with_context
import logging
import sqlite3
from modules.nmap_scans import run_nmap_scan, get_nmap_scan_types, get_nmap_options, get_old_nmap_results, manage_nmap_results

def register_nmap_routes(app):
    @app.route('/nmap', methods=['GET', 'POST'])
    def nmap_scan():
        if request.method == 'POST':
            target = request.form['target'].strip()
            scan_type = request.form.get('scan_type')
            options = request.form.getlist('options')
            custom_command = request.form.get('custom_command')

            logging.debug(f"Received scan_type: {scan_type}")
            if not scan_type:
                logging.error("No scan type selected. Redirecting back to Nmap scan page.")
                return redirect(url_for('nmap_scan'))

            # Store in session
            session['nmap_target'] = target
            session['nmap_scan_type'] = scan_type
            session['nmap_options'] = options
            session['nmap_custom_command'] = custom_command

            return redirect(url_for('nmap_progress'))

        scan_types = get_nmap_scan_types()
        options = get_nmap_options()
        return render_template('nmap.html', scan_types=scan_types, options=options)

    @app.route('/nmap/progress')
    def nmap_progress():
        target = session.get('nmap_target', '').strip()
        scan_type = session.get('nmap_scan_type', '')
        options = session.get('nmap_options', [])
        custom_command = session.get('nmap_custom_command', '')

        logging.debug(f"Progress page called with scan_type: {scan_type}, target: {target}, options: {options}, custom_command: {custom_command}")

        return render_template('nmap_loading.html', target=target, scan_type=scan_type, options=options, custom_command=custom_command)

    @app.route('/nmap/stream')
    def nmap_stream():
        target = session.get('nmap_target', '').strip()
        scan_type = session.get('nmap_scan_type', '')
        options = session.get('nmap_options', [])
        custom_command = session.get('nmap_custom_command', '')

        options = [opt for opt in options if opt]

        if not scan_type:
            return "No scan type provided.", 400

        def generate():
            try:
                for output in run_nmap_scan(target, scan_type, options, custom_command):
                    yield f"data: {output}\n\n"
            except Exception as e:
                yield f"data: Error during scan: {e}\n\n"
            finally:
                yield "data: Scan completed\n\n"

        return Response(stream_with_context(generate()), content_type='text/event-stream')

    @app.route('/nmap/results')
    def nmap_results():
        try:
            results = get_old_nmap_results()
            return render_template('nmap_results.html', results=results)
        except Exception as e:
            return f"Error loading Nmap results: {e}"

    @app.route('/nmap/results/<int:result_id>')
    def nmap_result_detail(result_id):
        try:
            conn = sqlite3.connect('/nsatt/storage/databases/nmap_results.db')
            c = conn.cursor()
            c.execute('SELECT * FROM nmap_results WHERE id = ?', (result_id,))
            result = c.fetchone()
            conn.close()

            if result:
                return render_template('nmap_result_detail.html', result=result)
            else:
                return f"Result with ID {result_id} not found."

        except Exception as e:
            return f"Error loading Nmap result details: {e}"

    @app.route('/nmap/manage_results', methods=['GET', 'POST'])
    def manage_nmap_results_route():
        action = request.form.get('action')
        selected_ids = request.form.getlist('selected_scans')
        message = manage_nmap_results(action, selected_ids)
        return render_template('nmap_results.html', message=message)