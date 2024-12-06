locals {
    domain_guid = replace(var.domain, ".", "-")
    o365_mx   = format("0 %s.mail.protection.outlook.com", local.domain_guid)
    custom_mx_record = ["0 mx0a-00370801.pphosted.com", "0 mx0b-00370801.pphosted.com"]
    o365_spf  = "include:spf.protection.outlook.com"
    root_txt_values = ["MS=ms000000"]
    dkim_dom  = format("%s._domainkey.%s.onmicrosoft.com", local.domain_guid, var.tenant_name)
    dkim = [
        {
            name  = format("selector1._domainkey.%s", var.domain)
            value = "v=DKIM1; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA464yLk5C8ee+gPNAHuAtyxdmDFjYmd\"\"gh9lfWHbX1PrgHpHVWQbaOkTgmDjJWNAXK2BnZx5G6zfGWcryLB7WMDw++OfN8I4NXDFwGY4qtRsFSr6spp4DGCGMAKWri53F5MGbftYBAPQK8FP/Ia8XXOQtMZj3khkbJdJhLkljLXkoO7eac\"\"WVmdA3ACn6tvp1cmoM/fJY7XZQ06mvLIkyfrxHPfZTcrr7yPD2Kp/A09Lgr3IsBL4Vr361XMX9z60w8cCdybV\"\"do3McLBI7NEz7Lrj6Hs/MMT2yu4N5K9zWiu9YT19DJKvrh1S67kI1rW+O1J65mBmIM8176ieVhxpkO3CQIDAQAB"
        },
        {
            name  = format("selector2._domainkey.%s", var.domain)
            value =  "v=DKIM1; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAraYCCCxCQBZbRhOGJNcL6M/9Pk54Bo\"\"nkvIFLA6WWlKAtvR53OxhdWF9jDyAzC55LqMr1Zb1Q3eRsrz9M0QnrfKqpRABEoDWqm66jlb72+v3hexURddMwfrqqrt4oqA4V2xHjKHkb03rfLe9+Zf8Vlf0A2TQzb9Ca34CNvRA6Npe8bcZj\"\"fBxzHr9kIOrxFTb52dd+R+qB16odU6ZQJxGrTpH5El8KA4biFWbcnCQDofu2KF4/5TSwmeQG12NKVHjtqzO\"\"AJlDh5eC9al4LHbhxSUJLiePa0Tz4lKahalXXLkEa0A1T1Kvy876xXhWd0pAVSuqptdOFgDfPlh8ezRM88wIDAQAB"
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
    count   = var.enable_exchange && var.enable_custom_mx ? 1 : 0

    zone_id = var.zone_id
    name    = ""
    records = local.custom_mx_record
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
