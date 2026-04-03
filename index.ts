

if (process.argv.length > 2) {
    const filename = process.argv[2]

    if (filename === 'gen00ff') {
        for (let i = 0; i <= 0xff; i++) {
            process.stdout.write(Buffer.from([i]));
        }
        process.exit()
    }

    const stream = require('fs').createReadStream(filename)

    run(stream)
} else {
    run(process.stdin)
}

function run(readable_stream) {

    let buffer_alignment = 0;
    let space_alignment = 0;
    let row_alignment = 0;
    let line = "";

    function toTermEscape(str) {
        const r = Number.parseInt('0x' + str.substr(1, 2));
        const g = Number.parseInt('0x' + str.substr(3, 2));
        const b = Number.parseInt('0x' + str.substr(5, 2));

        return `\033[38;2;${r};${g};${b}m`;
    }

    const colors = {
        '00': toTermEscape('#9F9F9F'),
        '0x': toTermEscape('#FF77A9'),
        '1x': toTermEscape('#FF7777'),
        '2x': toTermEscape('#FF852F'),
        '3x': toTermEscape('#F89100'),
        '4x': toTermEscape('#EC9B00'),
        '5x': toTermEscape('#C3B100'),
        '6x': toTermEscape('#87C335'),
        '7x': toTermEscape('#63C858'),
        '8x': toTermEscape('#41CC6C'),
        '9x': toTermEscape('#00CF8D'),
        'Ax': toTermEscape('#00D0BB'),
        'Bx': toTermEscape('#00CAE9'),
        'Cx': toTermEscape('#00BEFF'),
        'Dx': toTermEscape('#53AFFF'),
        'Ex': toTermEscape('#B794FF'),
        'Fx': toTermEscape('#E97FE6'),
        'FF': toTermEscape('#FFFFFF')
    }

    function getColorForHex(v) {
        switch (v) {
            case 0x00:
                return colors['00'];
            case 0xff:
                return colors['FF'];
            default:
                return nbr_colors[v >> 4];
        }
    }

    const nbr_colors = [
        colors['0x'],
        colors['1x'],
        colors['2x'],
        colors['3x'],
        colors['4x'],
        colors['5x'],
        colors['6x'],
        colors['7x'],
        colors['8x'],
        colors['9x'],
        colors['Ax'],
        colors['Bx'],
        colors['Cx'],
        colors['Dx'],
        colors['Ex'],
        colors['Fx']
    ];

    const reset = '\033[0m'

    const close_on_pipe = (e) => {
        if (e) {

        }
    }

    readable_stream.on('data', (d) => {
        const len = d.length;
        for (let i = 0; i < len; i++) {
            if (row_alignment === 0) {
                process.stdout.write(buffer_alignment.toString(16).padStart('00000000'.length, '0') + ': ', close_on_pipe)
            }

            const code = d.at(i)!;
            if (code >= ' '.charCodeAt(0) && code <= '~'.charCodeAt(0)) {
                line += String.fromCharCode(code);
            } else {
                line += '.';
            }

            let prefix = getColorForHex(code);
            let suffix = reset;

            process.stdout.write(prefix + code.toString(16).padStart(2, '0') + suffix, close_on_pipe)
            space_alignment += 1;
            row_alignment += 1;
            buffer_alignment += 1;
            if (row_alignment === 16) {
                process.stdout.write('  ' + line + '\n', 'utf8', close_on_pipe)
                space_alignment = 0;
                row_alignment = 0;
                line = '';
            } else if (space_alignment === 2) {
                process.stdout.write(' ', 'utf8', close_on_pipe)
                space_alignment = 0;
            }
        }
    })

    readable_stream.on('end', () => {
        const missing_bytes = (16 - row_alignment) % 16;
        const missing_spaces = missing_bytes / 2;
        if (missing_bytes > 0 || line.length > 0) {
            console.log(' '.repeat(missing_bytes * 2 + missing_spaces + 1) + line);
        }
    })
}