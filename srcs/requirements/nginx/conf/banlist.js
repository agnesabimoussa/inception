// Bonus: fail2ban writes banned IPs to /var/lib/inception-bans/<jail>.list.
// $banned is "1" when the client's IP is in one of these files.
const fs = require('fs');
const DIR = '/var/lib/inception-bans';

function isBanned(r) {
    let files;
    try {
        files = fs.readdirSync(DIR);
    } catch (e) {
        return '';   // no ban folder: nothing is banned
    }
    // Classic loop: Alpine's njs does not support for...of
    for (let i = 0; i < files.length; i++) {
        const f = files[i];
        if (!f.endsWith('.list'))
            continue;
        const ips = fs.readFileSync(DIR + '/' + f, 'utf8').split('\n');
        if (ips.indexOf(r.remoteAddress) !== -1)
            return '1';
    }
    return '';
}

export default { isBanned };
