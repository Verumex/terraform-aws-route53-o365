locals {
    domain_guid = replace(var.domain, ".", "-")
    o365_mx   = format("0 %s.mail.protection.outlook.com", local.domain_guid)
    custom_mx_record = ["0 mx0a-00370801.pphosted.com", "0 mx0b-00370801.pphosted.com"]
    o365_spf  = "include:spf.protection.outlook.com"
    dkim_dom  = format("%s._domainkey.%s.onmicrosoft.com", local.domain_guid, var.tenant_name)
    dkim = [
        {
            name  = format("s1._domainkey.%s", var.domain)
            value = "v=DKIM1\; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6mhwUlgv0FktFQJx3raiN50MA0s5wUzZ7pO/2jDGKxzS4haY612E7YYFoPFjeVftm8d1+P3u9QNawCrRQ49TGB4eMKz8W5ug/Q2PWTOOYwxDqADDQ9nB9a9A/iapPBEMhyXKkoQrwEuthpTERbIL+BHXnQim+k4u8/MUbAo2z7eNww/1e2Q+nwoivSxLF/6MD/iDRLDQFtTT4uKhJzJj37v0WuHe6iGkVtT0XG0ZyuzD6DvyhexqRgaoQeOuElHHK8Vx+qduzKCk0rd+T+MF9U7vC4fOw02FDTzDb5gyDfjRDdv3cE/DvXzQy5qQq4piI9lOO2UdPruFtMXtHP8tPwIDAQAB"
        },
        {
            name  = format("s2._domainkey.%s", var.domain)
            value =  "v=DKIM1\; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyy5XzeEgaUd7UpQZg01gk2z41kEUNvZhy5AtfHUoDIuNdJx7clS/xcyn5qj956WkHgJevvj+/4o9LH+Q/b89GllNaOGAb24FegupZDZ3Tk6W4FZO6ulAtvnm5SOfmx8YU+pOdErsyyi2FjyRT2rWgP+9ekVFJ+AAvbEokx0/bPMTW4KkMxi+OgqBP7MaRHtZubpFOgCrQKvYe2IV3laEDIAu164saEl4auK8M9NVHFHUNyZ7rR0xsvoH9RMuSk0Xxosx0rrIacnZ9yWzwGhUPe9z2OJiKCzizWNrXR55bIKMmnmHEAT34SWKXkRGRqlYJGQ6STetvakm9lT3G11xMwIDAQAB"
        },
    ]
    sfb = [
        {
            name   = "lyncdiscover"
            record = "webdir.online.lync.com"
            type   = "CNAME"
        },
        {
            name   = "sip"
            record = "sipdir.online.lync.com"
            type   = "CNAME"
        },
        {
            name   = "_sipfederationtls._tcp"
            record = "100 1 5061 sipfed.online.lync.com"
            type   = "SRV"
        },
        {
            name   = "_sip._tls"
            record = "100 1 443 sipdir.online.lync.com"
            type   = "SRV"
        }
    ]
    mdm = [
        {
            name   = "enterpriseregistration"
            record = "enterpriseregistration.windows.net"
        },
        {
            name   = "enterpriseenrollment"
            record = "enterpriseenrollment.manage.microsoft.com"
        }
    ]
}

#################
# Exchange Online
#################

resource "aws_route53_record" "mx" {
    count   = var.enable_exchange && !var.enable_custom_mx ? 1 : 0

    zone_id = var.zone_id
    name    = ""
    records = [local.o365_mx]
    type    = "MX"
    ttl     = var.ttl
}

resource "aws_route53_record" "custom_mx" {
    count   = var.enable_exchange && var.enable_custom_mx && length(local.custom_mx_record) > 0 ? 1 : 0

    zone_id = var.zone_id
    name    = ""
    records = [local.custom_mx_record]
    type    = "MX"
    ttl     = var.ttl
}

resource "aws_route53_record" "autodiscover" {
    count   = var.enable_exchange ? 1 : 0

    zone_id = var.zone_id
    name    = "autodiscover"
    records = ["autodiscover.outlook.com"]
    type    = "CNAME"
    ttl     = var.ttl
}

locals {
    ms_verification_text = length(var.ms_txt) > 0 ? "MS=${var.ms_txt}" : null
    full_spf             = var.enable_spf ? join(" ", concat(["v=spf1", local.o365_spf], var.custom_spf_includes, ["-all"])) : null
    root_txt_values      = compact([local.ms_verification_text, local.full_spf])
}

resource "aws_route53_record" "root_txt" {
    count   = length(local.root_txt_values) > 0 ? 1 : 0

    records = local.root_txt_values
    zone_id = var.zone_id
    name    = ""
    type    = "TXT"
    ttl     = var.ttl
}

resource "aws_route53_record" "dmarc" {
    count   = var.enable_exchange && var.enable_dmarc && length(var.dmarc_record) > 0 ? 1 : 0

    zone_id = var.zone_id
    name    = "_dmarc"
    records = [var.dmarc_record]
    type    = "TXT"
    ttl     = var.ttl
}

resource "aws_route53_record" "dkim" {
    count   = var.enable_exchange && var.enable_dkim && length(var.tenant_name) > 0 ? length(local.dkim) : 0

    zone_id = var.zone_id
    name    = lookup(local.dkim[count.index], "name")
    records = [lookup(local.dkim[count.index], "value")]
    type    = "TXT"
    ttl     = var.ttl
}

####################
# Skype for Business
####################

resource "aws_route53_record" "sfb" {
    count   = var.enable_sfb ? length(local.sfb) : 0

    zone_id = var.zone_id
    name    = lookup(local.sfb[count.index], "name")
    records = [lookup(local.sfb[count.index], "record")]
    type    = lookup(local.sfb[count.index], "type")
    ttl     = var.ttl
}

##########################
# Mobile Device Management
##########################

resource "aws_route53_record" "mdm" {
    count   = var.enable_mdm ? length(local.mdm) : 0

    zone_id = var.zone_id
    name    = lookup(local.mdm[count.index], "name")
    records = [lookup(local.mdm[count.index], "record")]
    type    = "CNAME"
    ttl     = var.ttl
}
