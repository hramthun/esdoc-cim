<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:UML="omg.org/UML1.3"
  exclude-result-prefixes="UML">

  <!-- output an XML file -->
  <xsl:output method="xml" indent="yes"/>

  <!-- ignore free text -->
  <xsl:template match="text()"/>

  <!-- EA outputs XMI v1.1; so this XSL is tailored to that -->
  <!-- strange things might happen at other versions -->
  <xsl:template match="XMI[@xmi.version='1.1']">
    <!-- apply templates to the UML:Model -->
    <!-- and ignore  UML:Diagram, etc. -->
    <xsl:apply-templates select="XMI.content/UML:Model"/>
  </xsl:template>

  <!-- uh-oh, XMI at a different version -->
  <xsl:template match="XMI">
    <xsl:message terminate="yes">unsupported XMI version</xsl:message>
  </xsl:template>

  <!-- just copy class documentation over -->
  <xsl:template match="UML:Package//UML:Class//UML:TaggedValue[@tag='documentation']">
    <xs:annotation>
      <xs:documentation>
        <xsl:value-of select="@value"/>
      </xs:documentation>
    </xs:annotation>
  </xsl:template>

  <!-- some useful global variables (for string comparisons) -->
  <xsl:variable name="lowerCase">abcdefghijklmnopqrstuvwxyz</xsl:variable>
  <xsl:variable name="upperCase">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
  <xsl:variable name="built-inTypes">Character CharacterString Integer Real Boolean URI</xsl:variable>

  <!-- create an XML attribute -->
  <xsl:template name="attributeTemplate">
    <xsl:param name="min"/>
    <xsl:param name="max"/>
    <xsl:param name="type"/>
    <xsl:param name="stereotype"/>
    <xsl:param name="namespace"/>

    <xs:attribute name="{@name}">
      <xsl:attribute name="use">
        <xsl:choose>
          <xsl:when test="$min=0">
            <xsl:text>optional</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>required</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="type">
        <xsl:value-of select="concat($namespace,':',$type)"/>
      </xsl:attribute>
    </xs:attribute>
    <xsl:apply-templates/>
  </xsl:template>


  <!-- create a (local) XML element -->
  <xsl:template name="elementTemplate">
    <xsl:param name="min"/>
    <xsl:param name="max"/>
    <xsl:param name="type"/>
    <xsl:param name="stereotype"/>
    <xsl:param name="namespace"/>

    <xsl:element name="xs:element">
      <xsl:attribute name="name">
        <xsl:value-of select="concat($namespace,':',@name)"/>
      </xsl:attribute>
      <xsl:attribute name="minOccurs">
        <xsl:value-of select="$min"/>
      </xsl:attribute>
      <xsl:attribute name="maxOccurs">
        <xsl:choose>
          <xsl:when test="string($max)='*'">
            <xsl:text>unbounded</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$max"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="type">
        <xsl:value-of select="concat($namespace,':',$type)"/>
      </xsl:attribute>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- create a (global) XML element -->
  <!-- handles the <<document>> stereotype -->
  <xsl:template name="documentTemplate">
    <xsl:param name="namespace"/>
    <!-- document x is just a global element of type complexType x -->
    <xs:element>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($namespace,':',@name)"/>
      </xsl:attribute>
      <xsl:attribute name="type">
        <xsl:value-of select="concat($namespace,':',@name)"/>
      </xsl:attribute>
    </xs:element>
  </xsl:template>

  <!-- how to process codelists -->
  <xsl:template name="codelistTemplate">
    <xsl:param name="namespace"/>
    <xs:simpleType>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($namespace,':',@name)"/>
      </xsl:attribute>
      <!-- a codelist is a union of xs:string... -->
      <xs:union>
        <xsl:attribute name="memberTypes">
          <xsl:text>xs:string </xsl:text>
          <xsl:value-of select="concat($namespace,':',@name,'CodeList')"/>
        </xsl:attribute>
      </xs:union>
    </xs:simpleType>
    <xs:simpleType>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($namespace,':',@name,'CodeList')"/>
      </xsl:attribute>
      <!-- ...and an enumeration -->
      <xs:restriction base="xs:string">
        <xsl:for-each select="descendant::UML:Attribute">
          <xsl:sort case-order="lower-first" select="@name"/>
          <xs:enumeration value="{@name}"/>
        </xsl:for-each>
      </xs:restriction>
    </xs:simpleType>
  </xsl:template>

  <!-- how to process enumerations -->
  <xsl:template name="enumerationTemplate">
    <xsl:param name="namespace"/>
    <xs:simpleType>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($namespace,':',@name)"/>
      </xsl:attribute>
      <xs:restriction base="xs:string">
        <xsl:for-each select="descendant::UML:Attribute">
          <xsl:sort case-order="lower-first" select="@name"/>
          <xs:enumeration value="{@name}"/>
        </xsl:for-each>
      </xs:restriction>
    </xs:simpleType>
  </xsl:template>

  <!-- create an XML complexType -->
  <!-- all classes (that aren't codelists or enumerations) are complexTypes -->
  <xsl:template name="complexTypeTemplate">
    <xsl:param name="namespace"/>
    <xsl:param name="id"/>
    
    <xs:complexType>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($namespace,':',@name)"/>
      </xsl:attribute>

      <xs:sequence>
        <!-- check if any attributes should be elements -->
        <xsl:for-each select="descendant::UML:Attribute">
          <xsl:sort case-order="lower-first" select="@name"/>
          <xsl:variable name="attMin" select="descendant::UML:TaggedValue[@tag='lowerBound']/@value"/>
          <xsl:variable name="attMax" select="descendant::UML:TaggedValue[@tag='upperBound']/@value"/>
          <xsl:variable name="attType" select="descendant::UML:TaggedValue[@tag='type']/@value"/>
          <xsl:variable name="attStereotype"
            select="translate(descendant::UML:TaggedValue[@tag='stereotype']/@value,$upperCase,$lowerCase)"/>

          <!-- A UML attribute is an XML element, unless it is of type x-->
          <!-- where x is an enumeration, codelist, or built-in type. -->
          <!-- Otherwise it is an XML attribute, -->
          <!-- unless it has an upperBound > 1 -->

          <!-- this convoluted test makes sure that... -->
          <!-- there the upperBound is greater than one -->
          <!-- or it is an explicit enumeration or codlist  -->
          <xsl:if
            test="$attMax!=1         
            or not(($attStereotype='enumeration' or $attStereotype='codelist')
            or (//UML:Class[@name=$attType]//UML:Stereotype/@name='enumeration' or //UML:Class[@name=$attType]//UML:Stereotype/@name='codelist'))">
            <xsl:call-template name="elementTemplate">
              <xsl:with-param name="min" select="$attMin"/>
              <xsl:with-param name="max" select="$attMax"/>
              <xsl:with-param name="type" select="$attType"/>
              <xsl:with-param name="stereotype" select="$attStereotype"/>
              <xsl:with-param name="namespace" select="$namespace"/>
            </xsl:call-template>
          </xsl:if>
        </xsl:for-each>

        <!-- check there are any associations which have this class as an endpoint -->
        <xsl:apply-templates select="//UML:Association/UML:Association.connection/UML:AssociationEnd[1][@type=$id]" mode="association">
          <xsl:with-param name="class" select="."/>
        </xsl:apply-templates>          

      </xs:sequence> <!-- ends the section of a complexType where local elements are listed, we can now proceed to local attributes -->

      <!-- check if any attributes should be attributes  -->
      <!-- (should be the inverse of the 1st for-each loop) -->
      <xsl:for-each select="descendant::UML:Attribute">
        <xsl:sort case-order="lower-first" select="@name"/>
        <xsl:variable name="attMin" select="descendant::UML:TaggedValue[@tag='lowerBound']/@value"/>
        <xsl:variable name="attMax" select="descendant::UML:TaggedValue[@tag='upperBound']/@value"/>
        <xsl:variable name="attType" select="descendant::UML:TaggedValue[@tag='type']/@value"/>
        <xsl:variable name="attStereotype"
          select="translate(descendant::UML:TaggedValue[@tag='stereotype']/@value,$upperCase,$lowerCase)"/>

        <!-- this convoluted test is the inverse of that above -->
        <xsl:if
          test="$attMax=1 and 
          (($attStereotype='enumeration' or $attStereotype='codelist') 
          or (//UML:Class[@name=$attType]//UML:Stereotype/@name='enumeration' or //UML:Class[@name=$attType]//UML:Stereotype/@name='codelist'))">
          <xsl:call-template name="attributeTemplate">
            <xsl:with-param name="min" select="$attMin"/>
            <xsl:with-param name="max" select="$attMax"/>
            <xsl:with-param name="type" select="$attType"/>
            <xsl:with-param name="stereotype" select="$attStereotype"/>
            <xsl:with-param name="namespace" select="$namespace"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:for-each>
    </xs:complexType>
  </xsl:template>

  <!-- every package is a new schema -->
  <!-- TODO: use the document() command to output schemas to separate files -->
  <xsl:template match="UML:Package">
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
      targetNamespace="http://metaforclimate.eu/cim/{@name}">
      <xsl:apply-templates/>
    </xs:schema>
  </xsl:template>

  <!-- every UML class within a package is either a complexType or a simpleType -->
  <!-- <<document>> stereotypes are also global elements -->
  <xsl:template match="UML:Package//UML:Class">

    <xsl:variable name="packageID" select="descendant::UML:TaggedValue[@tag='package']/@value"/>
    <xsl:variable name="classID" select="@xmi.id"/>

    <xsl:variable name="classStereotype"
      select="translate(./UML:ModelElement.taggedValue/UML:TaggedValue[@tag='stereotype']/@value,$upperCase,$lowerCase)"/>
    <xsl:variable name="classNamespace" select="//UML:Package[@xmi.id=$packageID]/@name"/>

    <xsl:choose>
      <xsl:when test="$classStereotype='enumeration'">
        <xsl:call-template name="enumerationTemplate">
          <xsl:with-param name="namespace" select="$classNamespace"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$classStereotype='codelist'">
        <xsl:call-template name="codelistTemplate">
          <xsl:with-param name="namespace" select="$classNamespace"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>

        <xsl:call-template name="complexTypeTemplate">
          <xsl:with-param name="namespace" select="$classNamespace"/>
          <xsl:with-param name="id" select="$classID"/>
        </xsl:call-template>

      </xsl:otherwise>
    </xsl:choose>
    <xsl:if test="$classStereotype='document'">
      <xsl:call-template name="documentTemplate">
        <xsl:with-param name="namespace" select="$classNamespace"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
